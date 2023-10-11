local core = require("apisix.core")
local plugin = require("apisix.plugin")
local ngx = ngx
local redis = require "resty.redis"


local plugin_name = "delete-from-redis"


local schema = {
    type = "object",
    properties = {
        body = {
            description = "body to replace response.",
            type = "string"
        },
    },
    required = {"body"},
}


local _M = {
    version = 0.5,
    priority = 13,
    name = plugin_name,
    schema = schema,
}


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


function _M.access(conf, ctx)
    local req_body, _ = core.request.get_body(max_body_size, ctx)
    local i, j = string.find(req_body, '9')
    local number = string.sub(req_body, i, i+9)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect("redis", 6379)

    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return
    end

    local ok, err = redis_client:del(number)
    if not ok then
        core.log.warn("failed to set number: ", err)
        return
    end

    local ok, err = redis_client:close()

    return 200, number
end


return _M