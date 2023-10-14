local core = require("apisix.core")
local plugin = require("apisix.plugin")
local ngx = ngx
local cjson = require("cjson.safe")
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
    data, err = cjson.decode(req_body)
    if err then
        core.log.warn("Invalid json: ", err)
        return 400, "Malformed request"
    end

    if not data["number"] then
        core.log.warn("'number' param must be provided")
        return 400, "'number' param must be provided"
    end

    local number = get_number_string(data["number"])
    
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

    
function edit_number(req_body)
    data, err = cjson.decode(req_body)
    if err then
        core.log.warn("Invalid json: ", err)
        return 400, "Malformed request"
    end

    if not data["number"] then
        core.log.warn("'number' param must be provided")
        return 400, "'number' param must be provided"
    end

    if not data["to"] then
        core.log.warn("'to' param must be provided")
        return 400, "'to' param must be provided"
    end

    local number = get_number_string(data["number"])
    local to_value = data["to"]
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, "Redis connection failure"
    end

    local ok, err = redis_client:set(number, to_value)
    if not ok then
        core.log.warn("failed to edit number: ", err)
        return 500, "Edit number in redis failed"
    end

    local ok, err = redis_client:close()

    return 200, number .. " updated"
end


function add_number_file(req_body)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, "Redis connection failure"
    end

    redis_client:init_pipeline()

    for line in string.gmatch(req_body,'[^\r\n]+') do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        if end_i ~= nil and start_i ~= nil then
            local value = string.sub(line, end_i + 1)
            value = value:gsub("%s+", "")
            value = string.gsub(value, "%s+", "")

            local number = string.sub(line, start_i, end_i - 1)

            redis_client:set(number, value)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, "Add numbers to redis failed"
    end

    local ok, err = redis_client:close()

    return 200, 'Numbers added'
end


function delete_number_file(req_body)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, "Redis connection failure"
    end

    redis_client:init_pipeline()

    for line in string.gmatch(req_body,'[^\r\n]+') do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        if end_i ~= nil and start_i ~= nil then
            local number = string.sub(line, start_i, end_i - 1)

            redis_client:del(number)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, "Delete numbers from redis failed"
    end

    local ok, err = redis_client:close()

    return 200, 'Numbers deleted'
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
        elseif req_method == "PUT" then
            return edit_number(req_body)
        else
            return 405, "Method not allowed"
        end
    elseif query_string["type"] == "file" then
        if req_method == "POST" then
            return add_number_file(req_body)
        elseif req_method == "DELETE" then
            return delete_number_file(req_body)
        else
            return 405, "Method not allowed"
        end
    else
        return 400, "'type' param must be provided"
    end

    return 200, nil
end


return _M