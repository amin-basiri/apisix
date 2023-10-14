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


local function get_number_string(str)
    local i, j = string.find(str, '9')
    local number = string.sub(str, i, i+9)

    return number
end


local function add_number(req_body)
    local data, err = cjson.decode(req_body)
    if err then
        core.log.warn("Invalid json: ", err)
        return 400, {msg="Malformed request"}
    end

    if not data["number"] then
        core.log.warn("'number' param must be provided")
        return 400, {msg="'number' param must be provided"}
    end

    local number = get_number_string(data["number"])
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local ok, err = redis_client:set(number, "H")
    if not ok then
        core.log.warn("failed to set number: ", err)
        return 500, {msg="Set number to redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg=number .. " added"}
end


local function get_number(query_string)
    local number

    if query_string["number"] then
        number = query_string["number"]
    else
        return 400, {msg="'number' param must be provided"}
    end

    number = get_number_string(number)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local value, err = redis_client:get(number)
    if not value then
        core.log.warn("failed to get number: ", err)
        return 500, {msg="Get number from redis failed"}
    end

    local ok, err = redis_client:close()

    if value == cjson.null then
        value = "E"
    end

    return 200, {[number]=value}
end


local function delete_number(query_string)
    local number

    if query_string["number"] then
        number = query_string["number"]
    else
        return 400, {msg="'number' param must be provided"}
    end

    number = get_number_string(number)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local ok, err = redis_client:del(number)
    if not ok then
        core.log.warn("failed to delete number: ", err)
        return 500, {msg="Delete number from redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg=number .. " deleted"}
end

    
local function edit_number(req_body)
    local data, err = cjson.decode(req_body)
    if err then
        core.log.warn("Invalid json: ", err)
        return 400, {msg="Malformed request"}
    end

    if not data["number"] then
        core.log.warn("'number' param must be provided")
        return 400, {msg="'number' param must be provided"}
    end

    if not data["to"] then
        core.log.warn("'to' param must be provided")
        return 400, {msg="'to' param must be provided"}
    end

    local number = get_number_string(data["number"])
    local to_value = data["to"]
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local ok, err = redis_client:set(number, to_value)
    if not ok then
        core.log.warn("failed to edit number: ", err)
        return 500, {msg="Edit number in redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg=number .. " updated"}
end


local function set_number_file(req_body)

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

            local number = string.sub(line, start_i, end_i - 1)

            redis_client:set(number, value)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Add numbers to redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg='Numbers added'}
end


local function delete_number_file(req_body)

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
            local number = string.sub(line, start_i, end_i - 1)

            redis_client:del(number)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Delete numbers from redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg='Numbers deleted'}
end

 
local function get_number_file(req_body)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    local numbers = {}
    local counter = 1

    for line in string.gmatch(req_body,'[^\r\n]+') do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        if end_i ~= nil and start_i ~= nil then
            local number = string.sub(line, start_i, end_i - 1)

            redis_client:get(number)

            numbers[counter] = number
            counter = counter + 1 
        end
    end
    
    local value, err = redis_client:commit_pipeline()
    if not value then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Get numbers from redis failed"}
    end

    local ok, err = redis_client:close()

    local number_values = {}

    for i=1, counter - 1 do
        if value[i] == cjson.null then
            number_values[numbers[i]] = "E"
        else
            number_values[numbers[i]] = value[i]
        end
    end

    return 200, cjson.encode(number_values)
end


local function set_number_batch(req_body)
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
        return 500, {msg="Set numbers to redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg="Numbers updated"}
end


local function get_number_batch(query_string)
    local numbers

    if query_string["numbers"] then
        numbers = query_string["numbers"]
    else
        return 400, {msg="'numbers' param must be provided"}
    end
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    local _numbers = {}
    local counter = 1

    for number in string.gmatch(numbers, '([^,]+)') do
        number = number:gsub("%s+", "")
        number = string.gsub(number, "%s+", "")
        redis_client:get(number)
        _numbers[counter] = number
        counter = counter + 1
    end

    local value, err = redis_client:commit_pipeline()
    if not value then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Get numbers from redis failed"}
    end

    local ok, err = redis_client:close()

    local number_values = {}

    for i=1, counter - 1 do
        if value[i] == cjson.null then
            number_values[_numbers[i]] = "E"
        else
            number_values[_numbers[i]] = value[i]
        end
    end

    return 200, cjson.encode(number_values)
end


local function delete_number_batch(query_string)
    local numbers

    if query_string["numbers"] then
        numbers = query_string["numbers"]
    else
        return 400, {msg="'numbers' param must be provided"}
    end
    
    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    redis_client:init_pipeline()

    for number in string.gmatch(numbers, '([^,]+)') do
        redis_client:del(number)
    end

    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Delete numbers from redis failed"}
    end

    local ok, err = redis_client:close()

    return 200, {msg="Numbers deleted"}
end


function _M.access(conf, ctx)
    local query_string = core.request.get_uri_args(ctx)
    local req_method = ctx.var.request_method
    local req_body, _ = core.request.get_body(max_body_size, ctx)

    core.response.set_header("Content-Type", "application/json")

    if query_string["type"] == "normal" then
        if req_method == "POST" then
            return add_number(req_body)
        elseif req_method == "GET" then
            return get_number(query_string)
        elseif req_method == "DELETE" then
            return delete_number(query_string)
        elseif req_method == "PUT" then
            return edit_number(req_body)
        else
            return 405, {msg="Method not allowed"}
        end
    elseif query_string["type"] == "file" then
        if req_method == "POST" then
            return set_number_file(req_body)
        elseif req_method == "DELETE" then
            return delete_number_file(req_body)
        elseif req_method == "GET" then
            return get_number_file(req_body)
        else
            return 405, {msg="Method not allowed"}
        end
    elseif query_string["type"] == "batch" then
        if req_method == "POST" then
            return set_number_batch(req_body)
        elseif req_method == "GET" then
            return get_number_batch(query_string)
        elseif req_method == "DELETE" then
            return delete_number_batch(query_string)
        else
            return 405, {msg="Method not allowed"}
        end
    else
        return 400, {msg="'type' param must be provided"}
    end

    return 200, {}
end


return _M