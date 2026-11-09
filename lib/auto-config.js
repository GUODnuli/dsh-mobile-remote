/**
 * 零配置接入（装上插件就能用）。
 *
 * 以前要让手机连上，用户得：手写 `cordis.patch.yml` 启用插件 → 自己生成口令 → 桌面版还要手写 lanBridge →
 * 自己去查 IP。这里把「必须由人决定」之外的部分全部自动化，且都是**纯函数 + 显式输入**，便于单测：
 *
 *   - `authToken: "@auto"`   首次启动随机生成强口令并持久化，之后复用（手机只需配对一次）。
 *   - `lanBridge.enabled: "auto"`   仅在需要时开桥（桌面版 webserver 只听回环）。
 *   - `formatConnectionBanner`   启动时把手机 App 需要填的两项（地址 + 口令）打印出来。
 *
 * 向后兼容：`authToken` 为空仍然表示「关闭认证」、`lanBridge.enabled` 仍可写 true/false；
 * 这些「自动」值只会出现在插件自带的 `cordis.patch.yml` 里，已有手写配置的用户行为不变。
 */
import { randomBytes } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/** 配置里写这个值 = 「请自动生成并持久化口令」。刻意带 `@`：不会和人手写的口令撞车。 */
export const AUTO = "@auto";

/** 自动口令的合法形态：24 字节 base64url = 32 字符；读回时按此校验，损坏的文件视为不存在。 */
const SAVED_TOKEN_RE = /^[A-Za-z0-9_-]{24,128}$/;

const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "::1"]);

/** 插件的状态目录。与宿主同一个 `DSH_HOME` 约定（隔离测试/多实例时口令不串）。 */
export function mobileRemoteStateDir(env = process.env, home = homedir()) {
	const base = typeof env.DSH_HOME === "string" && env.DSH_HOME.trim() !== "" ? env.DSH_HOME : join(home, ".dsh");
	return join(base, "mobile-remote");
}

/**
 * 解析 `authToken`。
 *  - 不是 `@auto`：原样返回（空串 = 关闭认证，保持旧语义）。
 *  - `@auto`：读 `<stateDir>/auth-token`；没有或损坏就生成新的并原子写入（0600）。
 *    写盘失败不阻断启动：本次进程内用内存口令，但会返回 `persistError`，调用方应提示
 *    「重启后口令会变，手机需要重新配对」。
 */
export function resolveAuthToken(configured, { dir = mobileRemoteStateDir(), generate = () => randomBytes(24).toString("base64url") } = {}) {
	if (configured !== AUTO) return { token: configured ?? "", auto: false };
	const file = join(dir, "auth-token");
	try {
		if (existsSync(file)) {
			const saved = readFileSync(file, "utf8").trim();
			if (SAVED_TOKEN_RE.test(saved)) return { token: saved, auto: true, generated: false, file };
		}
	} catch {
		// 读失败 → 当作没有，走下面的重新生成
	}
	const token = generate();
	try {
		mkdirSync(dir, { recursive: true, mode: 0o700 });
		const tmp = `${file}.${process.pid}.tmp`;
		writeFileSync(tmp, `${token}\n`, { mode: 0o600 });
		renameSync(tmp, file);
		return { token, auto: true, generated: true, file };
	} catch (persistError) {
		return { token, auto: true, generated: true, file: undefined, persistError };
	}
}

/**
 * 解析 `lanBridge.enabled`：true/false 原样；`"auto"` = 需要才开。
 * 「需要」= webserver 只听回环（桌面版强制如此，手机直连不了）。web 版 webserver 已经听 0.0.0.0，
 * 再开桥反而会和它抢同一个端口。宿主地址拿不到时按桌面版处理，但桥端口与 webserver 端口相同则不开。
 */
export function resolveLanBridgeEnabled(setting, { webHost, webPort, bridgePort } = {}) {
	if (setting !== "auto") return Boolean(setting);
	if (typeof webHost === "string" && webHost !== "") return LOOPBACK_HOSTS.has(webHost.toLowerCase());
	return !(webPort !== undefined && bridgePort === webPort);
}

/**
 * 自动开桥时选桥端口。桥默认端口 3080 与 `dsh web` 自己的 webserver 端口（回环 3080）相同：
 * macOS/BSD 允许「回环 3080」与「通配 3080」并存，Linux 却会 EADDRINUSE（Windows 行为也不可依赖）。
 * 所以 `auto` 模式下撞端口就让到下一个；用户**显式**写 true/false 时一律尊重其端口，不替人改。
 */
export function resolveLanBridgePort(setting, port, webPort) {
	if (setting === "auto" && webPort !== undefined && port === webPort) return port < 65535 ? port + 1 : port - 1;
	return port;
}

/**
 * 启动时打印给人看的「手机 App 要填的两项」。
 * 口令只在**自动生成**时打印——那是用户唯一能第一时间拿到它的地方；用户自己写进配置的口令不进日志。
 */
export function formatConnectionBanner({ addresses, token, tokenIsAuto, tokenFile, persistError, authEnabled = true }) {
	const [first, ...rest] = addresses;
	const lines = ["mobile-remote ▶ 手机 App 连接信息 / Phone app connection"];
	lines.push(`  电脑地址 Address : ${first}`);
	for (const extra of rest) lines.push(`                     ${extra}  (备用 alternative)`);
	if (!authEnabled) {
		lines.push("  访问口令 Token   : （未启用认证 / authentication is OFF）");
	} else if (tokenIsAuto) {
		lines.push(`  访问口令 Token   : ${token}`);
		if (persistError) {
			lines.push("  ⚠ 口令无法写入磁盘：重启后会变化，手机需要重新配对 / token could not be saved and changes on restart");
		} else if (tokenFile) {
			lines.push(`  （口令保存在 ${tokenFile}，重启不变 / persisted across restarts）`);
		}
	} else {
		lines.push("  访问口令 Token   : （你在配置里设置的 authToken / the authToken you configured）");
	}
	lines.push("  App：设置 → 重新配置连接，填入上面两项；或在 DSH 设置页「连接移动端设备」扫二维码 / scan the QR in DSH settings");
	return lines.join("\n");
}
