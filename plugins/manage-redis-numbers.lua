local core = require("apisix.core")
local plugin = require("apisix.plugin")
local ngx = ngx
local redis = require "resty.redis"


local plugin_name = "manage-redis-numbers"


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


function get_number_string(str)
    local i, j = string.find(str, '9')
    local number = string.sub(str, i, i+9)

    return number
end


function add_number(req_body)
    local number = get_number_string(req_body)
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, "Redis connection failure"
    end

    local ok, err = redis_client:set(number, "H")
    if not ok then
        core.log.warn("failed to set number: ", err)
        return 500, "Set number to redis failed"
    end

    local ok, err = redis_client:close()

    return 200, number .. " added"
end


function get_number(number)
    local number = get_number_string(number)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, "Redis connection failure"
    end

    local value, err = redis_client:get(number)
    if not value then
        core.log.warn("failed to get number: ", err)
        return 500, "Get number to redis failed"
    end

    local ok, err = redis_client:close()

    return 200, value
end


function delete_number(number)
    local number = get_number_string(number)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, "Redis connection failure"
    end

    local ok, err = redis_client:del(number)
    if not ok then
        core.log.warn("failed to delete number: ", err)
        return 500, "Delete number to redis failed"
    end

    local ok, err = redis_client:close()

    return 200, number .. " deleted"
end

    

function _M.access(conf, ctx)
    local query_string = core.request.get_uri_args(ctx)
    local req_method = ctx.var.request_method
    local req_body, _ = core.request.get_body(max_body_size, ctx)

    if query_string["type"] == "normal" then
        if req_method == "POST" then
            return add_number(req_body)
        elseif req_method == "GET" then
            if query_string["number"] then
                return get_number(query_string["number"])
            else
                return 400, "'number' param must be provided"
            end
        elseif req_method == "DELETE" then
            if query_string["number"] then
                return delete_number(query_string["number"])
            else
                return 400, "'number' param must be provided"
            end
        else
            return 405, "Method not allowed"
        end
    else
        return 400, "'type' param must be provided"
    end

    return 200, nil
end


return _M