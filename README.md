# 小鹤双拼 for Windows 微软拼音

收录网上公开的小鹤双拼注册表方案，并提供 Scoop 安装时自动导入、原配置备份和恢复功能。
适用于 Windows 10/11 的**微软拼音（简体中文）**，需要事先添加该输入法。

## Scoop 安装

```powershell
scoop bucket add li-sky https://github.com/li-sky/scoop-bucket
scoop install li-sky/xiaohe-shuangpin
```

安装会自动导入 `xiaohe-shuangpin.reg`，启用双拼并选中小鹤方案，无需再双击文件。
只修改当前用户的 `HKEY_CURRENT_USER`，不需要管理员权限，不支持 `scoop install -g`。
如果输入法未立即刷新，切换输入法后重试，或注销后重新登录。

只修改 `HKCU\Software\Microsoft\InputMethod\Settings\CHS` 的三个值：

| 注册表值 | 安装后的值 |
| --- | --- |
| `Enable Double Pinyin` | DWORD `1`，启用双拼 |
| `DoublePinyinScheme` | DWORD `10`，选择自定义方案 0 |
| `UserDefinedDoublePinyinScheme0` | 小鹤双拼键位映射 |

已有的自定义方案 0 会被小鹤替换；首次安装会备份这三个值（包含原本不存在的情况），重复安装或更新不会覆盖原备份。
候选词、词库、云候选等其他设置不变。

## 恢复原配置

```powershell
xiaohe-shuangpin -Mode Restore
```

这会恢复安装前的三个值，并清除已经使用的备份。若之后又手动修改过这三个值，恢复仍以首次备份为准。
重新执行 `xiaohe-shuangpin` 可再次备份并启用小鹤。

备份默认保存在 `$HOME\scoop\persist\xiaohe-shuangpin\data\registry-backup.json`（自定义 Scoop 目录时相应变化）。
普通 `scoop uninstall xiaohe-shuangpin` **保留当前输入法配置及备份**；如果想恢复原设置，请先执行上面的恢复命令再卸载。

## 不使用 Scoop

下载 Release 中的 ZIP 并解压，在 PowerShell 中运行：

```powershell
.\configure.ps1
# 恢复
.\configure.ps1 -Mode Restore
```

也可以直接双击 `xiaohe-shuangpin.reg` 导入，但直接导入不会自动备份。
`.reg` 使用 UTF-16 LE（带 BOM），避免中文方案名乱码；脚本兼容 Windows PowerShell 5.1 与 PowerShell 7。

## 来源

- 注册表内容来自 [gntzh 的小鹤双拼 Windows 11 Gist](https://gist.github.com/gntzh/b9a38b98ed97a2a3addee7c9827e503a)，采用其“添加”文件的三个值，改为适合 Windows 导入的 UTF-16 LE 编码。
- 键位映射交叉核对：[2015WUJI01/xhup-for-win10](https://github.com/2015WUJI01/xhup-for-win10/tree/81b8dd9e1beab0f6fd6b17f02bbd1754d12ca305)。
- 导入命令参考 [Microsoft reg import 文档](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/reg-import)。

这是社区方案的整理与安装封装，不是微软或小鹤官方发布。来源未明确指定许可证，Scoop 清单标记为 `Unknown`。

## 维护

运行 `python scripts/package.py` 生成可重复的 ZIP 和 SHA-256 文件。
`tests/windows.ps1` 在 Windows 上验证实际注册表导入、中文值、原配置恢复、重复安装备份，以及 Scoop 自动导入与卸载保留行为。
发布前，更新版本号与 `scoop/xiaohe-shuangpin.json` 的版本、下载地址和 SHA-256；验证通过后创建对应 Release，并将清单同步到个人 bucket。
