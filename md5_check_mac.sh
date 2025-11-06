#!/bin/bash

# ==============================================
# MD5 Bulk Verification Script for macOS
# ==============================================

LOG_FILE="Metagenomics_MD5_Verification_$(date +%Y-%m-%d_%H-%M-%S).txt"

# 初始化统计信息
TOTAL_FOLDERS=0
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
MISSING_FILES=0
ALL_PASSED=true

# 创建日志头
{
    echo "=============================================="
    echo "Metagenomics MD5 Bulk Verification Report (macOS)"
    echo "=============================================="
    echo "Execution Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Working Directory: $(pwd)"
    echo "Computer Name: $(hostname)"
    echo "Username: $(whoami)"
    echo "Operating System: $(sw_vers -productName) $(sw_vers -productVersion)"
    echo ""
} | tee "$LOG_FILE"

echo "搜索MD5文件..." | tee -a "$LOG_FILE"

# 查找所有MD5文件
MD5_FILES=($(find . -name "*_MD5.txt" -type f))

if [ ${#MD5_FILES[@]} -eq 0 ]; then
    echo "错误: 未找到任何MD5文件！" | tee -a "$LOG_FILE"
    exit 1
fi

echo "找到 ${#MD5_FILES[@]} 个MD5文件" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

TOTAL_FOLDERS=${#MD5_FILES[@]}
FOLDER_INDEX=0

# 处理每个MD5文件
for md5file in "${MD5_FILES[@]}"; do
    FOLDER_INDEX=$((FOLDER_INDEX + 1))
    FOLDER_PATH=$(dirname "$md5file")
    FOLDER_NAME=$(basename "$FOLDER_PATH")
    
    FOLDER_PASSED=true
    FOLDER_FILE_COUNT=0
    FOLDER_PASSED_COUNT=0
    FOLDER_FAILED_COUNT=0
    FOLDER_MISSING_COUNT=0

    {
        echo "=============================================="
        echo "处理 [$FOLDER_INDEX/$TOTAL_FOLDERS]: $FOLDER_NAME"
        echo "文件夹路径: $FOLDER_PATH"
        echo "=============================================="
    } | tee -a "$LOG_FILE"

    # 进入文件夹
    cd "$FOLDER_PATH"
    
    FILE_INDEX=0
    
    # 读取MD5文件的每一行
    while IFS= read -r line; do
        # 跳过空行和注释行
        line_trimmed=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ -z "$line_trimmed" || "$line_trimmed" =~ ^# ]]; then
            continue
        fi
        
        # 解析MD5和文件名 (格式: MD5哈希 文件名)
        if [[ "$line_trimmed" =~ ^([a-fA-F0-9]{32})[[:space:]]+(.+)$ ]]; then
            FILE_INDEX=$((FILE_INDEX + 1))
            TOTAL_FILES=$((TOTAL_FILES + 1))
            FOLDER_FILE_COUNT=$((FOLDER_FILE_COUNT + 1))
            
            expected_md5="${BASH_REMATCH[1],,}"  # 转换为小写
            filename="${BASH_REMATCH[2]}"
            
            # 清理文件名路径
            filename=$(echo "$filename" | sed 's|^\./||' | sed 's|^\.\\||')
            
            echo -n "文件 [$FILE_INDEX]: $filename" | tee -a "$LOG_FILE"
            
            if [[ -f "$filename" ]]; then
                # 计算文件大小
                file_size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)
                size_mb=$(echo "scale=2; $file_size / 1048576" | bc 2>/dev/null || echo "0")
                
                echo -n " - 计算MD5..." | tee -a "$LOG_FILE"
                
                # 计算实际MD5 (macOS)
                actual_md5=$(md5 -q "$filename")
                
                if [[ "$actual_md5" == "$expected_md5" ]]; then
                    echo " 通过" | tee -a "$LOG_FILE"
                    echo "✅ $filename: OK (大小: ${size_mb} MB)" | tee -a "$LOG_FILE"
                    PASSED_FILES=$((PASSED_FILES + 1))
                    FOLDER_PASSED_COUNT=$((FOLDER_PASSED_COUNT + 1))
                else
                    echo " 失败" | tee -a "$LOG_FILE"
                    {
                        echo "❌ $filename: 校验失败 (大小: ${size_mb} MB)"
                        echo "   期望: $expected_md5"
                        echo "   实际: $actual_md5"
                    } | tee -a "$LOG_FILE"
                    FAILED_FILES=$((FAILED_FILES + 1))
                    FOLDER_FAILED_COUNT=$((FOLDER_FAILED_COUNT + 1))
                    FOLDER_PASSED=false
                    ALL_PASSED=false
                fi
            else
                echo " 文件不存在" | tee -a "$LOG_FILE"
                echo "❌ $filename: 文件不存在" | tee -a "$LOG_FILE"
                MISSING_FILES=$((MISSING_FILES + 1))
                FOLDER_MISSING_COUNT=$((FOLDER_MISSING_COUNT + 1))
                FOLDER_PASSED=false
                ALL_PASSED=false
            fi
        else
            echo "警告: 跳过格式错误的行: $line_trimmed" | tee -a "$LOG_FILE"
        fi
    done < "$(basename "$md5file")"
    
    # 输出文件夹总结
    if $FOLDER_PASSED; then
        summary="✅ 文件夹总结: 所有文件验证成功! 文件: $FOLDER_FILE_COUNT/$FOLDER_FILE_COUNT 通过"
        echo "$summary" | tee -a "$LOG_FILE"
    else
        summary="❌ 文件夹总结: 验证发现问题! 通过: $FOLDER_PASSED_COUNT, 失败: $FOLDER_FAILED_COUNT, 缺失: $FOLDER_MISSING_COUNT"
        echo "$summary" | tee -a "$LOG_FILE"
    fi
    
    echo "" | tee -a "$LOG_FILE"
    
    # 返回原始目录
    cd - > /dev/null
done

# 计算成功率
SUCCESS_RATE=0
if [ $TOTAL_FILES -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=2; $PASSED_FILES * 100 / $TOTAL_FILES" | bc)
fi

# 生成最终报告
{
    echo "=============================================="
    echo "MD5验证最终报告"
    echo "=============================================="
    echo "总文件夹数: $TOTAL_FOLDERS"
    echo "总文件数: $TOTAL_FILES"
    echo "通过文件: $PASSED_FILES"
    echo "失败文件: $FAILED_FILES"
    echo "缺失文件: $MISSING_FILES"
    echo "成功率: $SUCCESS_RATE%"
    echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
} | tee -a "$LOG_FILE"

# 问题文件汇总
{
    echo "=============================================="
    echo "问题文件汇总"
    echo "=============================================="
} | tee -a "$LOG_FILE"

if $ALL_PASSED; then
    echo "🎉 未发现问题文件 - 所有文件验证通过!" | tee -a "$LOG_FILE"
else
    echo "⚠️  发现问题文件:" | tee -a "$LOG_FILE"
    echo "   失败: $FAILED_FILES 个文件" | tee -a "$LOG_FILE"
    echo "   缺失: $MISSING_FILES 个文件" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "详细日志已保存到: $LOG_FILE" | tee -a "$LOG_FILE"
echo "MD5批量验证完成!" | tee -a "$LOG_FILE"

# 显示日志位置
echo ""
echo "日志文件位置: $(pwd)/$LOG_FILE"
