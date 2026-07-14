# 余迹

一款原生 SwiftUI macOS 清理工具，用于查找应用卸载后的残留文件与缓存。

## 主要功能

- 扫描应用残留、缓存、日志、偏好设置等文件
- 结合应用名称、Bundle ID、更新时间和文件类型判断风险
- 保护系统目录、隐私数据与仍在使用的应用内容
- 支持搜索、筛选、白名单、扫描历史和 CSV 报告
- 清理内容移至废纸篓，便于恢复

“全选”会选择当前列表中的全部项目；风险等级仅作安全提醒。清理前请确认路径和提示信息。

## 下载安装

[下载最新版 DMG](https://github.com/linchenhao921019-ux/YuJi/releases/download/v2026.07.15/YuJi-macOS-arm64-v2026.07.15.dmg)

需要 macOS 15 或更高版本。打开 DMG，将“余迹”拖入“Applications”即可。当前版本尚未经过 Apple 公证，首次启动请右键应用并选择“打开”。扫描前请按提示授予“完全磁盘访问”权限。

## 源码构建

开发者需要 Swift 6.2：

```bash
./scripts/build-app.sh
./install_app_to_applications.sh
```

应用将安装到 `/Applications/余迹.app`。

## 安全说明

余迹采用保守扫描策略，并在清理前再次检查路径与保护规则。自动判断仍可能存在误差，请勿清理无法确认用途的重要内容。
