# MD5 Batch Verification Tool

Data Integrity Verification for Bioinformatics

## Key Findings

Critical Discovery: Direct cloud-to-external drive transfers have 53.8% failure rate

Transfer Method: Cloud → Mac Internal
Samples: 9/9
Success Rate: 100%
Result: ✅ All passed

Transfer Method: Cloud → Windows External  
Samples: 18/39
Success Rate: 46.2%
Result: ❌ 53.8% failed

## Quick Start

Mac Users:
- Open Terminal
- Go to your data folder: cd /your/data/folder  
- Run: ./md5_check_mac.sh

Windows Users:
- Open PowerShell
- Go to your data folder: cd C:\your\data\folder
- Run: .\md5_check_windows.ps1

## Scientific Impact

Discovered cloud-to-external storage transfers risk 53.8% data corruption, highlighting the importance of verification before bioinformatics analysis.

---

# MD5批量校验工具

生物信息学数据完整性验证

## 关键发现

重要发现：从云盘直接下载到移动硬盘存在53.8%的失败率

传输方式：云盘 → Mac 内置硬盘
样本数：9/9
成功率：100%
结果：✅ 全部通过

传输方式：云盘 → Windows 移动硬盘
样本数：18/39
成功率：46.2%
结果：❌ 53.8%失败

## 快速使用

Mac 用户：
- 打开终端
- 进入数据文件夹：cd /你的/数据/文件夹
- 运行：./md5_check_mac.sh

Windows 用户：
- 打开PowerShell
- 进入数据文件夹：cd C:\你的\数据\文件夹
- 运行：.\md5_check_windows.ps1

## 科学意义

发现从云盘直接传输到移动硬盘存在53.8%的数据损坏风险，强调了在生物信息学分析前进行数据验证的重要性。
