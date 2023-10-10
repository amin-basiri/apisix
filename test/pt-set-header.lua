local core = require("apisix.core")

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

local plugin_name = "pt-set-header"

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

    -- extract subscriber number from request body and create REDIS Key
    local indx = string.find(req_body, 'subscriberNumber', 1, true)
    indx = string.find(req_body, '>9', indx, true)
    local msisdn = string.sub(req_body, indx+1, indx+10)
    local esb_msisdn = "ESB_" .. msisdn

    -- THE REGEX WAY! (SLOWER!!)
    -- local esb_msisdn = "ESB_" .. req_body:match("<name>subscriberNumber</name>%s*<value>%s*<string>%d+</string>"):match("%d+")

    local config = {
    name = "esb", --rediscluster name
      serv_list = { --redis cluster node list(host and port),
          { ip = "10.130.219.70", port = 6379 },
          { ip = "10.130.219.71", port = 6379 },
          { ip = "10.130.219.70", port = 6380 }
      }, 
      read_only = true,
      keepalive_cons = 1000,                  --redis connection pool size
      connect_timeout = 1000,                 --timeout while connecting
      read_timeout = 1000,                    --timeout while reading
      send_timeout = 1000,                    --timeout while sending
      max_redirection = 5,                    --maximum retry attempts for redirection,
      max_connection_attempts = 1,            --maximum retry attempts for connection
      auth_user = "esb",     
      auth_password = "e6cc817c90b04587ed30638e3f45deec"
    }

    local redis_cluster = require "resty.rediscluster"

    local red_c, _ = redis_cluster:new(config)

    if not red_c then
        core.log.warn("failed to connect to redis cluster: ", err)
        return
    end

    local v, _ = red_c:get(esb_msisdn)

    if v == "H" then
        core.request.set_header("X-HE", "H")
        core.log.warn("X-HE Header SET TO: H")
    else
        core.request.set_header("X-HE", "E")
        core.log.warn("X-HE Header SET TO: ", "E")
    end

    return
end

return _M
