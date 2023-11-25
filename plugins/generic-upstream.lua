local core = require("apisix.core")
local plugin = require("apisix.plugin")
local upstream   = require("apisix.upstream")
local schema_def = require("apisix.schema_def")


local plugin_name = "generic-upstream"


local upstreams_schema = {
    type = "object",
    items = {
        type = "object",
        properties = {
            upstream_id = schema_def.id_schema,
        }
    }
}

local schema = {
    type = "object",
    properties = {
        upstreams = upstreams_schema
    },
}


local _M = {
    version = 0.1,
    priority = 0,
    name = plugin_name,
    schema = schema,
}


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


local function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

 
function _M.access(conf, ctx)
    local x_gd, _ = core.request.header(ctx, "X-GD")

    local upstream_id = conf["upstreams"][x_gd]["upstream_id"]

    if upstream_id then

        ctx.upstream_id = upstream_id
        ctx.var.upstream_uri = "/manage_redis_numbers"

        if ctx.var.args then
            ctx.var.upstream_uri = ctx.var.upstream_uri .. "?" .. ctx.var.args
        end
        
        core.log.warn(upstream_id)
    else
        core.log.warn(x_gd)
    end

end


return _M