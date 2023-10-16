local core = require("apisix.core")
local plugin = require("apisix.plugin")
local ngx = ngx
local cjson = require("cjson.safe")
local redis = require "resty.redis"


local plugin_name = "manage-redis-msisdns"


local schema = {}


local _M = {
    version = 0.5,
    priority = 13,
    name = plugin_name,
    schema = schema,
}

local redis_host = "redis"
local redis_port = 6379


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


local function get_msisdn_string(str)
    local i, j = string.find(str, '9')
    local msisdn = string.sub(str, i, i+9)

    return msisdn
end


local function add_msisdn(req_body)
    local data, err = cjson.decode(req_body)
    if err then
        core.log.warn("Invalid json: ", err)
        return 400, {msg="Malformed request"}
    end

    if not data["msisdn"] then
        core.log.warn("'msisdn' param must be provided")
        return 400, {msg="'msisdn' param must be provided"}
    end

    local msisdn = get_msisdn_string(data["msisdn"])
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local ok, err = redis_client:set(msisdn, "H")
    if not ok then
        core.log.warn("failed to set msisdn: ", err)
        return 500, {msg="Set msisdn to redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg=msisdn .. " added"}
end


local function get_msisdn(query_string)
    local msisdn

    if query_string["msisdn"] then
        msisdn = query_string["msisdn"]
    else
        return 400, {msg="'msisdn' param must be provided"}
    end

    msisdn = get_msisdn_string(msisdn)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local value, err = redis_client:get(msisdn)
    if not value then
        core.log.warn("failed to get msisdn: ", err)
        return 500, {msg="Get msisdn from redis failed"}
    end

    local ok, err = redis_client:close()

    if value == cjson.null then
        value = "E"
    end

    return 200, {[msisdn]=value}
end


local function delete_msisdn(query_string)
    local msisdn

    if query_string["msisdn"] then
        msisdn = query_string["msisdn"]
    else
        return 400, {msg="'msisdn' param must be provided"}
    end

    msisdn = get_msisdn_string(msisdn)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local ok, err = redis_client:del(msisdn)
    if not ok then
        core.log.warn("failed to delete msisdn: ", err)
        return 500, {msg="Delete msisdn from redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg=msisdn .. " deleted"}
end

    
local function edit_msisdn(req_body)
    local data, err = cjson.decode(req_body)
    if err then
        core.log.warn("Invalid json: ", err)
        return 400, {msg="Malformed request"}
    end

    if not data["msisdn"] then
        core.log.warn("'msisdn' param must be provided")
        return 400, {msg="'msisdn' param must be provided"}
    end

    if not data["to"] then
        core.log.warn("'to' param must be provided")
        return 400, {msg="'to' param must be provided"}
    end

    local msisdn = get_msisdn_string(data["msisdn"])
    local to_value = data["to"]
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local ok, err = redis_client:set(msisdn, to_value)
    if not ok then
        core.log.warn("failed to edit msisdn: ", err)
        return 500, {msg="Edit msisdn in redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg=msisdn .. " updated"}
end


local function set_msisdn_file(req_body)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    for line in string.gmatch(req_body,'[^\r\n]+') do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        if end_i ~= nil and start_i ~= nil then
            local value = string.sub(line, end_i + 1)
            value = value:gsub("%s+", "")
            value = string.gsub(value, "%s+", "")

            if value == "" then
                value = "H"
            end

            local msisdn = string.sub(line, start_i, end_i - 1)

            redis_client:set(msisdn, value)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Add msisdns to redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg='msisdns added'}
end


local function delete_msisdn_file(req_body)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    for line in string.gmatch(req_body,'[^\r\n]+') do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        if end_i ~= nil and start_i ~= nil then
            local msisdn = string.sub(line, start_i, end_i - 1)

            redis_client:del(msisdn)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Delete msisdns from redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg='msisdns deleted'}
end

 
local function get_msisdn_file(req_body)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    local msisdns = {}
    local counter = 1

    for line in string.gmatch(req_body,'[^\r\n]+') do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        if end_i ~= nil and start_i ~= nil then
            local msisdn = string.sub(line, start_i, end_i - 1)

            redis_client:get(msisdn)

            msisdns[counter] = msisdn
            counter = counter + 1 
        end
    end
    
    local value, err = redis_client:commit_pipeline()
    if not value then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Get msisdns from redis failed"}
    end

    local ok, err = redis_client:close()

    local msisdn_values = {}

    for i=1, counter - 1 do
        if value[i] == cjson.null then
            msisdn_values[msisdns[i]] = "E"
        else
            msisdn_values[msisdns[i]] = value[i]
        end
    end

    return 200, cjson.encode(msisdn_values)
end


local function set_msisdn_batch(req_body)
    local data, err = cjson.decode(req_body)
    if err then
        core.log.warn("Invalid json: ", err)
        return 400, {msg="Malformed request"}
    end
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    for k, v in pairs(data) do
        redis_client:set(k, v)
    end

    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Set msisdns to redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg="msisdns updated"}
end


local function get_msisdn_batch(query_string)
    local msisdns

    if query_string["msisdns"] then
        msisdns = query_string["msisdns"]
    else
        return 400, {msg="'msisdns' param must be provided"}
    end
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    local _msisdns = {}
    local counter = 1

    for msisdn in string.gmatch(msisdns, '([^,]+)') do
        msisdn = msisdn:gsub("%s+", "")
        msisdn = string.gsub(msisdn, "%s+", "")
        redis_client:get(msisdn)
        _msisdns[counter] = msisdn
        counter = counter + 1
    end

    local value, err = redis_client:commit_pipeline()
    if not value then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Get msisdns from redis failed"}
    end

    local ok, err = redis_client:close()

    local msisdn_values = {}

    for i=1, counter - 1 do
        if value[i] == cjson.null then
            msisdn_values[_msisdns[i]] = "E"
        else
            msisdn_values[_msisdns[i]] = value[i]
        end
    end

    return 200, cjson.encode(msisdn_values)
end


local function delete_msisdn_batch(query_string)
    local msisdns

    if query_string["msisdns"] then
        msisdns = query_string["msisdns"]
    else
        return 400, {msg="'msisdns' param must be provided"}
    end
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    for msisdn in string.gmatch(msisdns, '([^,]+)') do
        redis_client:del(msisdn)
    end

    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Delete msisdns from redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg="msisdns deleted"}
end


function _M.access(conf, ctx)
    local query_string = core.request.get_uri_args(ctx)
    local req_method = ctx.var.request_method
    local req_body, _ = core.request.get_body(max_body_size, ctx)

    core.response.set_header("Content-Type", "application/json")

    if query_string["type"] == "normal" then
        if req_method == "POST" then
            return add_msisdn(req_body)
        elseif req_method == "GET" then
            return get_msisdn(query_string)
        elseif req_method == "DELETE" then
            return delete_msisdn(query_string)
        elseif req_method == "PUT" then
            return edit_msisdn(req_body)
        else
            return 405, {msg="Method not allowed"}
        end
    elseif query_string["type"] == "file" then
        if req_method == "POST" then
            return set_msisdn_file(req_body)
        elseif req_method == "DELETE" then
            return delete_msisdn_file(req_body)
        elseif req_method == "GET" then
            return get_msisdn_file(req_body)
        else
            return 405, {msg="Method not allowed"}
        end
    elseif query_string["type"] == "batch" then
        if req_method == "POST" then
            return set_msisdn_batch(req_body)
        elseif req_method == "GET" then
            return get_msisdn_batch(query_string)
        elseif req_method == "DELETE" then
            return delete_msisdn_batch(query_string)
        else
            return 405, {msg="Method not allowed"}
        end
    else
        return 400, {msg="'type' param must be provided"}
    end

    return 200, {}
end


return _M