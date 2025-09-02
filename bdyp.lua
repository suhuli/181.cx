-- 引入HTTP处理模块和后端交互模块
local http = require 'http'
local backend = require 'backend'

-- 引入字符串操作函数，便于后续处理
local char = string.char
local byte = string.byte
local find = string.find
local sub = string.sub

-- 从后端模块获取地址、代理相关常量
local ADDRESS = backend.ADDRESS
local PROXY = backend.PROXY
local DIRECT_WRITE = backend.SUPPORT.DIRECT_WRITE

-- 从后端模块获取结果状态常量
local SUCCESS = backend.RESULT.SUCCESS    -- 操作成功状态
local HANDSHAKE = backend.RESULT.HANDSHAKE-- 握手状态
local DIRECT = backend.RESULT.DIRECT      -- 直接传输状态

-- 从后端模块获取上下文操作函数
local ctx_uuid = backend.get_uuid             -- 获取上下文唯一标识
local ctx_proxy_type = backend.get_proxy_type -- 获取代理类型
local ctx_address_type = backend.get_address_type -- 获取地址类型
local ctx_address_host = backend.get_address_host -- 获取主机地址
local ctx_address_bytes = backend.get_address_bytes -- 获取地址字节数据
local ctx_address_port = backend.get_address_port   -- 获取端口号
local ctx_write = backend.write              -- 向上下文写入数据
local ctx_free = backend.free                -- 释放上下文资源
local ctx_debug = backend.debug              -- 调试日志输出

-- 获取HTTP请求判断函数
local is_http_request = http.is_http_request

-- 定义状态存储表
local flags = {}  -- 用于存储连接的状态标志
local marks = {}  -- 预留标记存储表

-- 定义状态标志常量
local kHttpHeaderSent = 1     -- HTTP头部已发送标志
local kHttpHeaderRecived = 2  -- HTTP头部已接收标志

-- 标志回调函数：控制连接行为的标志位
-- 返回0表示使用默认行为
function wa_lua_on_flags_cb(ctx)
    return 0
end

-- 握手阶段回调函数：处理代理连接的握手过程
function wa_lua_on_handshake_cb(ctx)
    -- 获取当前上下文的唯一标识
    local uuid = ctx_uuid(ctx)

    -- 如果已接收到HTTP头部，则完成握手
    if flags[uuid] == kHttpHeaderRecived then
        return true
    end
    
    local res = nil  -- 用于存储要发送的HTTP请求内容

    -- 如果尚未发送HTTP头部，则构造并发送CONNECT请求
    if flags[uuid] ~= kHttpHeaderSent then
        -- 获取目标主机和端口
        local host = ctx_address_host(ctx)
        local port = ctx_address_port(ctx)

        -- 构造CONNECT代理请求，包含特定服务地址和认证信息
        res = 'CONNECT ' .. host .. ':' .. port .. '@panservice.mail.wo.cn:443 HTTP/1.1\r\n' ..
              'Host: panservice.mail.wo.cn\r\n' ..
              'Proxy-Connection: Keep-Alive\r\n' ..
              'User-Agent: baiduboxapp\r\n' ..
              'X-T5-Auth: 99565244\r\n\r\n'
          
        -- 将构造的请求写入上下文（发送出去）
        ctx_write(ctx, res)
        -- 更新状态为HTTP头部已发送
        flags[uuid] = kHttpHeaderSent
    end

    -- 返回false表示握手尚未完成
    return false
end

-- 读取数据回调函数：处理接收到的数据
function wa_lua_on_read_cb(ctx, buf)
    -- 获取当前上下文的唯一标识
    local uuid = ctx_uuid(ctx)
    
    -- 如果处于HTTP头部已发送状态，则更新为已接收状态，并返回握手完成
    if flags[uuid] == kHttpHeaderSent then
        flags[uuid] = kHttpHeaderRecived
        return HANDSHAKE, nil
    end

    -- 其他情况直接传输数据
    return DIRECT, buf
end
