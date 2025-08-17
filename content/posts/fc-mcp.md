---
title: "Function Calling与MCP协议：AI助手工具调用的进化之路"
date: 2025-08-17T12:00:00Z
draft: false
tags: ["AI", "Function Calling", "MCP", "工具调用", "API设计", "协议设计"]
author: "Aster"
description: "深入解析Function Calling和Model Context Protocol (MCP)的设计原理，探讨AI助手如何从简单对话进化到强大的工具调用能力。"
---

# Function Calling与MCP协议：AI助手工具调用的进化之路

最近在研究AI助手的工具调用能力时，发现了一个很有意思的技术演进路径：从最初大模型只能"聊天"，到现在能够调用各种外部工具，这背后的技术架构经历了怎样的变化？今天就来深入分析Function Calling和MCP协议这两个关键技术。

## 一、Function Calling：让AI学会使用工具

### 要解决的问题

传统的聊天大模型有个根本性限制：**只会说话，不会干活**。具体表现为：

1. **无法感知环境**：无法与外部数据源交互，比如查询网页、读取本地文件、访问数据库
2. **无法改变环境**：无法帮用户执行实际任务，比如运行代码、发送邮件、上传文件

这就像雇了一个只会纸上谈兵的顾问，能给建议但干不了实事。

### 传统解决方案的问题

最初的解决思路是**后端+LLM**模式：

![工作流程1.1](/images/工作流程1.1.png)

但这种方案存在明显问题：

1. **判断逻辑复杂**：是否调用工具、调用什么工具完全由后端负责，容易误判
2. **参数构建困难**：后端需要根据用户输入构建调用参数，实现复杂

既然AI这么智能，为什么不让它来判断和生成参数呢？

### Function Calling的解决方案

Function Calling分为两种实现方式：

#### 1. 基于提示词的Function Calling

通过精心设计的提示词让模型学会调用函数：

```
# 你的角色
你是一个函数调用助手，我将提供多个函数的定义信息。

# 你的任务
- 根据用户输入判断是否需要调用某个函数
- 如果需要，请严格按照以下格式输出：
```json
{ "name": "函数名", "arguments": { "参数名": "参数值" } }
```

# 函数定义信息
1. **get_weather**  
   - 作用：查询指定城市的天气情况  
   - 参数：city（string）：城市名称

用户："广州的天气怎么样？"
模型：{ "name": "get_weather", "arguments": { "city": "广州" } }
```

**存在的问题**：
- 输出格式不稳定
- 容易出现幻觉（编造不存在的函数）
- 上下文冗长，Token消耗大

#### 2. 基于API的Function Calling

大模型提供商在模型层面和API层面提供原生支持：

**工作流程**：

![工作流程1.2](/images/工作流程1.2)

1. **用户提问**："广州今天天气如何？适合出门吗？"

2. **第一次API调用**：获取函数调用指令
```json
{
  "messages": [
    {
      "role": "user",
      "content": "广州今天天气如何？适合出门吗？"
    }
  ],
  "functions": [
    {
      "name": "getWeather",
      "description": "获取指定城市的天气",
      "parameters": {
        "type": "object",
        "properties": {
          "location": {"type": "string", "description": "城市名称"},
          "date": {"type": "string", "description": "日期"}
        },
        "required": ["location", "date"]
      }
    }
  ]
}
```

3. **模型生成调用指令**：
```json
{
  "function_call": {
    "name": "getWeather",
    "arguments": {
      "location": "Guangzhou",
      "date": "2025-08-17"
    }
  }
}
```

4. **执行函数调用**：后端解析指令，调用实际函数

5. **第二次API调用**：将结果传回模型生成最终回复

![工作流程1.3](/images/工作流程1.3)

## 二、MCP协议：工具调用的标准化革命

### MCP要解决的问题

Function Calling虽然解决了AI调用工具的能力问题，但又产生了新的工程问题：

1. **工具接入的冗余开发**：每接入一个新工具，都要完整copy代码和函数描述
2. **工具复用困难**：环境问题、源码获取、跨语言调用等障碍
3. **标准化缺失**：不同AI应用接入同一工具的方式不统一

### MCP的设计思路

MCP (Model Context Protocol) 的核心思想是：**既然工具调用这么通用，为什么不制定一个标准协议？**

就像USB-C统一了设备连接标准一样，MCP想要统一AI应用与工具的连接标准。

#### 技术方案思路

1. **解耦合**：工具与AI应用彻底分离
2. **标准化交互**：
   - 统一通信协议（本地/远程）
   - 统一接口定义
   - 统一数据格式
   - 统一配置方式

### MCP核心架构

![系统架构设计1.1](/images/系统架构设计1.1)

MCP遵循**客户端-服务器架构**：

- **MCP Host**：AI应用程序，协调和管理多个MCP Client
- **MCP Client**：维护与MCP Server的连接，获取上下文信息
- **MCP Server**：提供具体工具和资源的程序

**关键特性**：
- 每个Client与Server保持一对一连接
- Server可以运行在本地或远程
- 支持动态工具发现和更新通知

### 传输协议设计

![系统1.2](/images/系统1.2)

MCP支持两种传输机制：

#### 1. Stdio传输（本地）
- 基于标准输入/输出流的进程间通信
- 使用管道(pipe)连接进程
- 零网络开销，性能最优

#### 2. Streamable HTTP传输（远程）
- 基于HTTP POST + Server-Sent Events
- 支持标准HTTP认证  
- 支持流式数据传输

![必须选用以上传输协议吗配图](/images/必须选用以上传输协议吗配图.png)

### 标准化配置

**本地服务接入示例**：
```json
{
  "mcpServers": {
    "amap-maps": {
      "command": "npx",
      "args": ["-y", "@amap/amap-maps-mcp-server"],
      "env": {
        "AMAP_MAPS_API_KEY": "你的API密钥"
      }
    }
  }
}
```

**远程服务接入示例**：
```json
{
  "mcpServers": {
    "amap-maps-remote": {
      "url": "https://mcp.amap.com/mcp?key=你的API密钥"
    }
  }
}
```

### 标准化接口

MCP定义了统一的接口规范：

1. **tools/list**：返回可用工具列表
2. **tools/call**：执行具体工具调用
3. **notifications/tools/list_changed**：工具更新通知

数据格式统一使用**JSON-RPC 2.0**协议。

![MCP工作流程](/images/mcp工作流程.png)

## 三、从Function Calling到MCP的进化意义

### 解决的核心问题

1. **从重复开发到配置复用**：开发者只需添加一条配置就能接入工具
2. **从紧耦合到标准解耦**：工具和AI应用彻底分离
3. **从单一模型到生态开放**：任何符合MCP协议的工具都能被任何支持MCP的AI应用使用

### 技术架构的进化

```
传统方案：AI应用 ← 硬编码 → 工具代码
Function Calling：AI应用 ← API调用 → 工具函数  
MCP协议：AI应用 ← 标准协议 → 工具服务
```

### 生态价值

MCP协议的真正价值在于构建了一个**可插拔的AI工具生态**：

- **工具开发者**：只需实现一次MCP Server，就能被所有支持MCP的AI应用使用
- **AI应用开发者**：只需实现一次MCP Client，就能接入所有MCP工具
- **用户**：可以在不同AI应用间共享同一套工具配置

## 四、实际应用展望

随着MCP协议的推广，我们可以期待：

1. **工具市场化**：出现专门的MCP工具市场和生态
2. **AI应用标准化**：支持MCP成为AI应用的标配
3. **开发效率提升**：工具复用大大降低开发成本
4. **能力快速扩展**：AI应用能快速获得新的工具能力

## 总结

从Function Calling到MCP协议，我们看到了AI工具调用能力的完整进化路径：

- **Function Calling**解决了"AI能否调用工具"的问题
- **MCP协议**解决了"如何高效复用和标准化工具"的问题

这个进化过程很好地体现了软件工程的一个重要原则：**先解决功能问题，再解决工程问题，最后解决生态问题**。

MCP协议的出现，标志着AI工具调用从实验室走向了工业化标准，这对整个AI应用生态的发展具有重要意义。