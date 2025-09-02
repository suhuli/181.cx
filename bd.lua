-- 引入所需的模块：http 和 backend
local http = require 'http'
local backend = require 'backend'

-- 定义一些字符串操作函数
local char = string.char
local byte = string.byte
local find = string.find
local sub = string.sub

-- 从 backend 模块中获取一些常量和函数
local ADDRESS = backend.ADDRESS
local PROXY = backend.PROXY
local DIRECT_WRITE = backend.SUPPORT.DIRECT_WRITE

-- 从 backend 模块中获取一些结果常量
local SUCCESS = backend.RESULT.SUCCESS
local HANDSHAKE = backend.RESULT.HANDSHAKE
local DIRECT = backend.RESULT.DIRECT

-- 从 backend 模块中获取一些上下文相关的函数
local ctx_uuid = backend.get_uuid
local ctx_proxy_type = backend.get_proxy_type
local ctx_address_type = backend.get_address_type
local ctx_address_host = backend.get_address_host
local ctx_address_bytes = backend.get_address_bytes
local ctx_address_port = backend.get_address_port
local ctx_write = backend.write
local ctx_free = backend.free
local ctx_debug = backend.debug

-- 创建一个空表用于存储标志
local flags = {}

-- 定义两个标志的值
local kHttpHeaderSent = 1
local kHttpHeaderRecived = 2

-- 定义一个函数，用于根据上下文信息返回 Direct_Write 标志
function wa_lua_on_flags_cb(ctx)
    return DIRECT_WRITE
end

-- 定义一个函数，用于在握手阶段进行处理
function wa_lua_on_handshake_cb(ctx)
    -- 获取上下文的 UUID
    local uuid = ctx_uuid(ctx)

    -- 如果当前标志为已接收到 HTTP 头，则直接返回 true
    if flags[uuid] == kHttpHeaderRecived then
        return true
    end

    -- 如果当前标志不是已发送 HTTP 头，则构造 CONNECT 请求头并写入上下文
    if flags[uuid] ~= kHttpHeaderSent then
        -- 获取主机和端口信息
        local host = ctx_address_host(ctx)
        local port = ctx_address_port(ctx)
        -- 构造请求头
        local res = 'CONNECT ' .. host .. ':' .. port .. 'HTTP/1.1\r\n' ..
                    'Host: 183.240.98.84:443\r\n' ..
                    'Proxy-Connection: Keep-Alive\r\n'..
                    'X-T5-Auth: 683556433\r\n\r\n'
        -- 将请求头写入上下文
        ctx_write(ctx, res)
        -- 更新标志为已发送 HTTP 头
        flags[uuid] = kHttpHeaderSent
    end

    return false
end

-- 定义一个函数，用于处理读取数据的回调
function wa_lua_on_read_cb(ctx, buf)
    ctx_debug('wa_lua_on_read_cb')
    -- 获取上下文的 UUID
    local uuid = ctx_uuid(ctx)
    -- 如果当前标志为已发送 HTTP 头，则更新标志为已接收到 HTTP 头，并返回握手结果和 nil
    if flags[uuid] == kHttpHeaderSent then
        flags[uuid] = kHttpHeaderRecived
        return HANDSHAKE, nil
    end
    -- 否则，返回直接传递数据和 buf
    return DIRECT, buf
end

-- 定义一个函数，用于处理写入数据的回调
function wa_lua_on_write_cb(ctx, buf)
    ctx_debug('wa_lua_on_write_cb')
    -- 返回直接传递数据和 buf
    return DIRECT, buf
end

-- 定义一个函数，用于处理关闭连接的回调
function wa_lua_on_close_cb(ctx)
    ctx_debug('wa_lua_on_close_cb')
    -- 获取上下文的 UUID
    local uuid = ctx_uuid(ctx)
    -- 将对应的标志置为空，并释放上下文资源
    flags[uuid] = nil
    ctx_free(ctx)
    -- 返回成功结果
    return SUCCESS
end
