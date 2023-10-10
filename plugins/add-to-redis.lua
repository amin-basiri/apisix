local apisix = require("apisix")
local core = require("apisix.core")

local plugin_name = "add-to-redis"

local schema = {
    type = "object",
    properties = {
        i = {type = "number", minimum = 0},
    },
    required = {"i"},
}

-- local metadata_schema = {
--     type = "object",
--     properties = {
--         ikey = {type = "number", minimum = 0},
--         skey = {type = "string"},
--     },
--     required = {"ikey", "skey"},
-- }

local _M = {
    version = 0.1,
    priority = 0,
    name = plugin_name,
    schema = schema,
    -- metadata_schema = metadata_schema,
}


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


function _M.access(conf, ctx)
    core.log.error("heeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeey")
    core.log.warn(core.json.encode(ctx, true))
    return 200, conf.body
end


function _M.init()
    core.log.error("shuuuuuuuuuuuuuuuuuuuuuuuuuuuuuut")
end

function _M.log(conf, ctx)
    core.log.error("shiiiiiiiiiiiiiiiiiiiiiiiiit")
end

return _M



-- metadata schema
-- "metadata_schema": {
--     "properties": {
--         "ikey": {
--             "minimum": 0,
--             "type": "number"
--         },
--         "skey": {
--             "type": "string"
--         }
--     },
--     "required": [
--         "ikey",
--         "skey"
--     ],
--     "type": "object"
-- },