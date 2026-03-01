# 配置保存后网关重启逻辑与 Windows 下“未启动”说明

## 一、重启流程（你看到的日志对应关系）

1. **保存配置**  
   Dashboard 点击保存 → 写入 `C:\Users\gaoxu\.openclaw\openclaw.json`，并生成 `.bak` 备份。

2. **config.set 完成**  
   `[ws] ⇄ res ✓ config.set 95ms` 表示前端“保存”的 RPC 已成功。

3. **文件变更被检测**  
   `[reload] config change detected; evaluating reload (meta.lastTouchedAt, plugins)`  
   网关用 chokidar 监听配置文件，发现变更后对变更路径做一次“重载规则”匹配。

4. **判定需要整进程重启**  
   `[reload] config change requires gateway restart (plugins)`  
   在 `src/gateway/config-reload.ts` 里，`plugins` 前缀配置的规则是 `kind: "restart"`，因此会要求**整进程重启**（不能只做热重载）。

5. **发 SIGUSR1**  
   `emitGatewayRestart()` 会授权并发出 SIGUSR1（有 listener 时用 `process.emit("SIGUSR1")`，否则 `process.kill(process.pid, "SIGUSR1")`）。

6. **run-loop 处理 SIGUSR1**  
   - 日志：`[gateway] signal SIGUSR1 received` → `received SIGUSR1; restarting`  
   - 先 drain 进行中的任务（有超时），再 `server.close(...)`，然后进入 `handleRestartAfterServerClose()`。

7. **“全进程重启”**  
   - 释放端口锁 → 调用 `restartGatewayProcessWithFreshPid()`  
   - 在**非** `OPENCLAW_NO_RESPAWN`、**非** launchd/systemd 等托管环境下，会：  
     - 用当前 `process.execPath` 和当前 `argv` **spawn 一个 detached 子进程**（你看到的 `spawned pid 16084`）  
     - 父进程随后 `exit(0)`  
   - 所以日志里最后一条是：`restart mode: full process restart (spawned pid 16084)`，然后当前进程退出。

8. **子进程 16084**  
   子进程会重新执行同一条启动命令（例如 `node openclaw.mjs gateway run --port 18789`），重新读配置、拿锁、起服务。**你看到的“没有启动起来”是指这个子进程没有正常提供服务**，可能有两种情况（见下）。

---

## 二、为什么在 Windows 上“没启动起来”

可能原因有两类。

### 1. 控制台被关掉，子进程的输出了不可见（最常见）

- 父进程在 spawn 子进程后立刻 `exit(0)`，**当前控制台是父进程的**。  
- 在 Windows 上，父进程退出后，这个控制台窗口往往会关闭或不再显示输出。  
- 子进程是 `detached: true` + `stdio: "inherit"`，理论上继承父进程的 stdio，但父进程退出后，子进程要么：
  - 还在后台跑（端口可能已被占用或没监听），你看不到任何输出；要么  
  - 启动时报错（例如配置错误），错误打印到 stderr，但控制台已经没了，所以你看不到“为什么没起来”。

所以从现象上会像：“点了保存 → 网关说重启了 → 然后就没有然后了”。

### 2. 新配置导致子进程启动失败

- 子进程会重新读取**刚保存的那份** `openclaw.json`。  
- 若你在 Plugin 里改的某个属性不合法（类型错误、必填缺了、插件名拼错等），子进程可能在：  
  - 加载配置、校验配置、或加载插件时抛错并退出。  
- 同样，因为父进程已退出、控制台可能已关，这段错误信息往往看不到。

---

## 三、解决办法与建议

### 方案 A：用“进程内重启”，避免关控制台（推荐在 Windows 上开发时用）

让网关**不 spawn 新进程**，而是在当前进程里关掉 server、重新读配置、再起 server（in-process restart）。这样：

- 控制台一直是同一个，不会因为父进程退出而关掉。  
- 若新配置有错，启动错误会直接打在当前控制台。

做法：启动网关时加上环境变量：

```powershell
$env:OPENCLAW_NO_RESPAWN = "1"
node openclaw.mjs gateway run --port 18789 --verbose
```

或在同一 PowerShell 里先设再启动：

```powershell
$env:OPENCLAW_NO_RESPAWN = "1"; node openclaw.mjs gateway run --port 18789 --verbose
```

这样在“保存 Plugin 配置 → 触发重启”时，日志里会看到类似：

- `restart mode: in-process restart (OPENCLAW_NO_RESPAWN)`  
而不会出现 `restart mode: full process restart (spawned pid ...)`，也不会退出当前进程。  
若配置有误，你会直接在控制台看到报错。

### 方案 B：确认子进程是否在跑、配置是否合法

1. **看子进程是否还在**  
   保存并“重启”后，到任务管理器里查是否有**新的** `node` 进程（或你用的 `openclaw`/node 进程），PID 是否接近 16084（或日志里打印的 pid）。若没有，说明子进程已退出（多半是启动失败）。

2. **用当前配置手动起一次，看报错**  
   在**新的** PowerShell 里用**同一份**配置再起一次网关（不要设 `OPENCLAW_NO_RESPAWN`），例如：

   ```powershell
   node openclaw.mjs gateway run --port 18789 --verbose
   ```

   若配置有问题，这里会直接报错（例如插件加载失败、config 校验失败等）。根据报错修配置即可。

3. **检查刚保存的配置文件**  
   打开 `C:\Users\gaoxu\.openclaw\openclaw.json`，重点看 `plugins` 那块是否有明显错误（多余逗号、类型不对、拼写错误等）。若有 `.bak`，可以和当前文件对比。

---

## 四、相关代码位置（便于你或后续改代码）

| 步骤           | 文件 | 说明 |
|----------------|------|------|
| 为何 plugins 要整进程重启 | `src/gateway/config-reload.ts` | `BASE_RELOAD_RULES_TAIL` 里有 `{ prefix: "plugins", kind: "restart" }` |
| 变更检测与触发重启 | `src/gateway/config-reload.ts` | 文件 watch + `buildGatewayReloadPlan` + 调用方触发 `requestGatewayRestart` |
| 发 SIGUSR1 与 deferral | `src/gateway/server-reload-handlers.ts` | `requestGatewayRestart`、`emitGatewayRestart` |
| SIGUSR1 处理与 spawn | `src/cli/gateway-cli/run-loop.ts` | `onSigusr1` → `request("restart")` → `handleRestartAfterServerClose` → `restartGatewayProcessWithFreshPid()` |
| 真正 spawn 子进程 | `src/infra/process-respawn.ts` | `restartGatewayProcessWithFreshPid()`：`OPENCLAW_NO_RESPAWN=1` 时不 spawn，直接返回 disabled；否则 `spawn(process.execPath, args, { detached: true, stdio: "inherit" })` |

---

## 五、简短结论

- **重启逻辑**：保存配置 → 检测到 `plugins` 变更 → 要求整进程重启 → 发 SIGUSR1 → 当前进程关 server → spawn 子进程 → 父进程 exit(0)。子进程用同一命令行重新启动并读新配置。  
- **“没启动起来”** 在 Windows 上多半是：  
  1）父进程退出后控制台关了，子进程的启动/报错你看不到；或  
  2）新配置有误，子进程启动时报错退出。  
- **建议**：在 Windows 上开发时设 `OPENCLAW_NO_RESPAWN=1`，用进程内重启，便于在同一控制台看到所有日志和错误；若需要“真·全进程重启”，可先用手动再起一次网关的方式确认配置是否合法。
