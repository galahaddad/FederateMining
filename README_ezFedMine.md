EZ Fed Mine — One‑Click Monero P2Pool Miner
==========================================

What this is
------------
A single EXE (ezFedMine.exe) that:
- On first run, **downloads XMRig** for Windows (msvc‑win64) from GitHub.
- Writes a ready‑to‑go `config.json` pointing to **Ralph’s P2Pool mini node**.
- Launches XMRig and shows live mining logs in the console.
- On later runs, it **skips download** and starts mining immediately.

Hard‑coded target (by design)
-----------------------------
- **Pool:** ralphfederated.duckdns.org:37888 (P2Pool mini)
- **Wallet:** 48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk
- **Coin:** monero
- **Rig ID:** your Windows computer name (for identification in logs)

Payouts
-------
All rewards go directly to **Ralph’s wallet** above. This EXE is intended for friends who are donating hashpower.
The next roadmap item is creating a pool share distribution 

System requirements
-------------------
- Windows 10/11, 64‑bit
- Internet access (GitHub + pool)
- ~300 MB free RAM for RandomX cache (more is better)
- Optional: admin rights for best performance (huge pages)

How to run
----------
1) Double‑click **ezFedMine.exe**.
2) First run will show:
   - “XMRig not found… downloading…”
   - “Extraction complete”
   - “Writing config.json…”
   - “Launching XMRig…”
3) You’ll then see XMRig’s own console output (hashrate, accepted shares, etc.).
4) To stop: press **Ctrl+C** or close the window.

Files created
-------------
- `.\xmrig\` — folder next to ezFedMine.exe containing:
  - `xmrig.exe` and supporting files
  - `config.json` (pre‑filled)
- No registry keys, no services.

Troubleshooting
---------------
**SmartScreen/AV warning**
- Miners are common false positives. Click **More info → Run anyway**.
- If Defender quarantines it, add the folder to **Virus & threat protection → Exclusions**.

**Can’t connect to pool**
- In PowerShell, run:
  `Test-NetConnection ralphfederated.duckdns.org -Port 37888`
  - If it FAILS: Ralph’s port forward or firewall is closed. Ask Ralph to update the DNS.
  - If it SUCCEEDS: Your outbound network is fine; try again.

**No hashrate / very low hashrate**
- Wait ~30–60 seconds after startup; RandomX JIT warms up.
- Laptop “battery saver” or “balanced” power plans throttle CPU. Use **High performance** or **Ultimate Performance**.
- Close heavy apps (browsers/VMs) that compete for RAM/CPU.

**“Huge pages” not enabled**
- XMRig will still mine, but slower. For a boost:
  1) Run ezFedMine.exe **as Administrator**.
  2) Enable **Lock pages in memory** for your user:
     - Press **Win+R**, run `secpol.msc`
     - Local Policies → User Rights Assignment → Lock pages in memory → add your user → sign out/in.
  3) Re‑run; watch XMRig log for “huge pages” success.
  (If “Memory Integrity”/VBS is enabled in Windows Core Isolation, huge pages may be blocked—optional to leave as‑is.)

**Antivirus deletes XMRig after download**
- Add `.\xmrig\` to AV exclusions, then re‑run ezFedMine.exe.

**GPU mining**
- This package is CPU‑focused. XMRig can mine on GPUs with extra config/drivers. Not recommended here unless you know what you’re doing.

Verifying you’re mining to Ralph
--------------------------------
- XMRig line: `url=ralphfederated.duckdns.org:37888 user=48ZRL...` confirms pool+wallet.
- Accepted shares count will rise over time.
- Payout timing is probabilistic; P2Pool pays directly to the configured wallet upon block finds proportional to your shares.

Privacy & security
------------------
- The EXE fetches XMRig from GitHub’s **official** releases API on first run.
- No telemetry is added by this wrapper.
- Connections are: your PC → DuckDNS pool endpoint, and XMRig’s normal dev‑donation (1% default in config).

Uninstall
---------
- Close the miner, then delete:
  - `ezFedMine.exe`
  - the `xmrig\` folder beside it

Advanced (optional)
-------------------
- Rig name: change your Windows computer name to label your rig in logs, or edit `config.json`’s `"rig-id"` after first run.
- Log file: add `"log-file": "xmrig.log"` to `config.json` if you want persistent logs.
- Threads/affinity: XMRig auto‑tunes; advanced users can pin threads in `cpu` config for marginal gains.

Support
-------
If it won’t run or connect, send Ralph a screenshot of:
- The **first 30 lines** of ezFedMine’s console output, and
- The last 20 lines of XMRig’s console output.
