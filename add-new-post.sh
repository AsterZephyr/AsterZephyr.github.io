#!/bin/bash

# 新文章发布自动化脚本
# 使用方法: ./add-new-post.sh "文章标题" [文章文件路径]

set -e

# 配置变量
BLOG_DIR="/Users/hxz/code/Aster.github.io"
POSTS_DIR="$BLOG_DIR/content/posts"
STATIC_IMAGES_DIR="$BLOG_DIR/static/images"
TEMP_DIR="$BLOG_DIR/temp-new-post"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ 使用方法: ./add-new-post.sh \"文章标题\" [文章文件路径]${NC}"
    echo -e "${YELLOW}示例: ./add-new-post.sh \"Redis集群架构设计\" ./my-article.md${NC}"
    exit 1
fi

ARTICLE_TITLE="$1"
ARTICLE_FILE="$2"

echo -e "${BLUE}🚀 开始添加新文章: $ARTICLE_TITLE${NC}"

# 生成文件名 (URL友好)
SLUG=$(echo "$ARTICLE_TITLE" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | tr '[:upper:]' '[:lower:]')
TARGET_FILE="$POSTS_DIR/${SLUG}.md"

# 检查文件是否已存在
if [ -f "$TARGET_FILE" ]; then
    echo -e "${RED}❌ 文章已存在: $TARGET_FILE${NC}"
    exit 1
fi

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 如果提供了文章文件，复制到临时目录
if [ -n "$ARTICLE_FILE" ] && [ -f "$ARTICLE_FILE" ]; then
    cp "$ARTICLE_FILE" "$TEMP_DIR/article.md"
    ARTICLE_CONTENT=$(cat "$TEMP_DIR/article.md")
    echo -e "${GREEN}✅ 已读取文章文件: $ARTICLE_FILE${NC}"
else
    # 创建模板文章
    ARTICLE_CONTENT="# $ARTICLE_TITLE

## 概述

在这里写文章内容...

## 核心要点

- 要点1
- 要点2
- 要点3

## 总结

总结内容...
"
    echo -e "${YELLOW}📝 创建了文章模板，请稍后编辑内容${NC}"
fi

# 智能生成标签
generate_tags() {
    local title="$1"
    local content="$2"
    local tags=()
    
    # 基于标题和内容的关键词匹配
    if [[ "$title" =~ (Redis|缓存|Cache) ]] || [[ "$content" =~ (Redis|缓存|Cache) ]]; then
        tags+=("Redis" "缓存")
    fi
    
    if [[ "$title" =~ (MySQL|数据库|Database) ]] || [[ "$content" =~ (MySQL|数据库|Database) ]]; then
        tags+=("数据库" "MySQL")
    fi
    
    if [[ "$title" =~ (分布式|微服务|架构) ]] || [[ "$content" =~ (分布式|微服务|架构) ]]; then
        tags+=("分布式系统" "系统架构")
    fi
    
    if [[ "$title" =~ (性能|优化|Performance) ]] || [[ "$content" =~ (性能|优化|Performance) ]]; then
        tags+=("性能优化")
    fi
    
    if [[ "$title" =~ (网络|TCP|UDP|HTTP) ]] || [[ "$content" =~ (网络|TCP|UDP|HTTP) ]]; then
        tags+=("网络协议" "网络编程")
    fi
    
    if [[ "$title" =~ (Go|Golang) ]] || [[ "$content" =~ (Go|Golang) ]]; then
        tags+=("Go语言")
    fi
    
    if [[ "$title" =~ (K8S|Kubernetes|容器|Docker) ]] || [[ "$content" =~ (K8S|Kubernetes|容器|Docker) ]]; then
        tags+=("云原生" "容器技术")
    fi
    
    if [[ "$title" =~ (AI|机器学习|深度学习) ]] || [[ "$content" =~ (AI|机器学习|深度学习) ]]; then
        tags+=("人工智能" "机器学习")
    fi
    
    # 如果没有匹配到标签，添加默认标签
    if [ ${#tags[@]} -eq 0 ]; then
        tags+=("技术笔记")
    fi
    
    # 输出标签
    printf '%s\n' "${tags[@]}"
}

# 生成描述
generate_description() {
    local content="$1"
    local title="$2"
    
    # 提取第一段作为描述，限制在150字以内
    local first_paragraph=$(echo "$content" | grep -v "^#" | grep -v "^$" | head -1 | cut -c1-150)
    
    if [ -z "$first_paragraph" ]; then
        echo "深入探讨${title}的技术实现和最佳实践。"
    else
        echo "$first_paragraph"
    fi
}

# 生成标签和描述
tags_array=($(generate_tags "$ARTICLE_TITLE" "$ARTICLE_CONTENT"))
tags_str=""
for tag in "${tags_array[@]}"; do
    tags_str="$tags_str\"$tag\", "
done
tags_str=${tags_str%, }  # 移除最后的逗号和空格

description=$(generate_description "$ARTICLE_CONTENT" "$ARTICLE_TITLE")

# 获取当前时间（确保在当前时间之前）
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 创建完整的文章文件
cat > "$TARGET_FILE" << EOF
---
title: "$ARTICLE_TITLE"
date: $current_date
draft: false
tags: [$tags_str]
author: "Aster"
description: "$description"
---

$ARTICLE_CONTENT
EOF

echo -e "${GREEN}✅ 文章已创建: $TARGET_FILE${NC}"

# 处理图片
process_images() {
    echo -e "${YELLOW}🖼️  处理文章中的图片...${NC}"
    
    # 查找文章中的图片引用
    local image_refs=$(grep -o '!\[.*\](.*\.(png\|jpg\|jpeg\|gif\|svg))' "$TARGET_FILE" || true)
    
    if [ -n "$image_refs" ]; then
        echo "$image_refs" | while read -r img_ref; do
            # 提取图片路径
            local img_path=$(echo "$img_ref" | sed 's/.*(\(.*\))/\1/')
            
            # 如果是相对路径，尝试从文章目录或临时目录复制
            if [[ ! "$img_path" =~ ^https?:// ]] && [[ ! "$img_path" =~ ^/ ]]; then
                local source_img=""
                
                # 检查多个可能的源路径
                if [ -f "$(dirname "$ARTICLE_FILE")/$img_path" ]; then
                    source_img="$(dirname "$ARTICLE_FILE")/$img_path"
                elif [ -f "$TEMP_DIR/$img_path" ]; then
                    source_img="$TEMP_DIR/$img_path"
                elif [ -f "$img_path" ]; then
                    source_img="$img_path"
                fi
                
                if [ -n "$source_img" ] && [ -f "$source_img" ]; then
                    # 生成新的图片名称
                    local img_name=$(basename "$img_path")
                    local new_img_path="/images/${SLUG}/${img_name}"
                    local target_img_dir="$STATIC_IMAGES_DIR/$SLUG"
                    
                    # 创建目标目录
                    mkdir -p "$target_img_dir"
                    
                    # 复制图片
                    cp "$source_img" "$target_img_dir/$img_name"
                    
                    # 更新文章中的图片路径
                    sed -i '' "s|$img_path|$new_img_path|g" "$TARGET_FILE"
                    
                    echo -e "${GREEN}  ✅ 图片已处理: $img_name -> $new_img_path${NC}"
                else
                    echo -e "${RED}  ❌ 图片未找到: $img_path${NC}"
                fi
            fi
        done
    else
        echo -e "${YELLOW}  ℹ️  未发现需要处理的图片${NC}"
    fi
}

# 处理图片
process_images

# 清理临时目录
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ 文章添加完成！${NC}"
echo -e "${BLUE}📄 文件位置: $TARGET_FILE${NC}"
echo -e "${BLUE}🏷️  标签: $tags_str${NC}"
echo -e "${BLUE}📝 描述: $description${NC}"

# 询问是否立即提交
echo ""
read -p "是否立即提交到Git并推送？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}📤 提交到Git...${NC}"
    cd "$BLOG_DIR"
    git add .
    git commit -m "添加新文章: $ARTICLE_TITLE

- 自动生成标签: $tags_str
- 处理图片资源
- 优化SEO描述"
    git push origin main
    echo -e "${GREEN}✅ 已推送到远程仓库${NC}"
else
    echo -e "${YELLOW}ℹ️  请稍后手动提交: git add . && git commit -m \"添加新文章: $ARTICLE_TITLE\" && git push${NC}"
fi

echo -e "${GREEN}🎉 完成！您的新文章已准备就绪${NC}"
