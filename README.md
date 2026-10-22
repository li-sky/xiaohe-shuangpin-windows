# Windows 微软拼音小鹤双拼

为 Windows 10/11 的微软拼音导入并启用小鹤双拼。需先添加微软拼音（简体中文）输入法。

## 使用

下载 [xiaohe-shuangpin.reg](xiaohe-shuangpin.reg)，双击导入；也可以在 PowerShell 中运行：

```powershell
reg import .\xiaohe-shuangpin.reg
```

文件使用 UTF-16 LE 编码，只修改当前用户 `HKCU\Software\Microsoft\InputMethod\Settings\CHS` 的三个值：启用双拼、选中自定义方案 0、写入小鹤键位。已有的自定义方案 0 会被替换，手动导入前请自行备份。
如果输入法未立即刷新，切换输入法或注销后重新登录。

## Scoop 安装

自动导入及备份恢复逻辑由 [li-sky/scoop-bucket](https://github.com/li-sky/scoop-bucket) 维护：

```powershell
scoop bucket add li-sky https://github.com/li-sky/scoop-bucket
scoop install li-sky/xiaohe-shuangpin
```

通过 Scoop 安装后，运行 `xiaohe-shuangpin -Mode Restore` 可恢复安装前的设置。普通卸载保留输入法配置和备份。

## 来源

注册表内容来自 [gntzh 的小鹤双拼 Windows 11 Gist](https://gist.github.com/gntzh/b9a38b98ed97a2a3addee7c9827e503a)，键位映射与 [2015WUJI01/xhup-for-win10](https://github.com/2015WUJI01/xhup-for-win10/tree/81b8dd9e1beab0f6fd6b17f02bbd1754d12ca305) 交叉核对。
