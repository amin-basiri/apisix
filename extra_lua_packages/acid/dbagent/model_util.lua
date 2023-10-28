local arg_util = require('acid.dbagent.arg_util')
local sql_util = require('acid.dbagent.sql_util')
local sql_constructor = require('acid.sql_constructor')
local dbagent_conf = require('dbagent_conf')

local string_format = string.format

local _M = {}


function _M.setup_models()
    local models = dbagent_conf.models

    for _, subject_model in pairs(models) do
        local raw_fields = subject_model.fields

        local fields, err, errmsg = sql_constructor.make_fields(raw_fields)
        if err ~= nil then
            ngx.log(ngx.ERR, string_format('failed to make fields: %s, %s',
                                           err, errmsg))
            return nil, err, errmsg
        end

        for _, field in pairs(fields) do
            arg_util.build_field_schema(field)
        end

        subject_model.fields = fields
    end

    return true, nil, nil
end


function _M.choose_model(api_ctx)
    local models = dbagent_conf.models

    local subject_model = models[api_ctx.subject]
    if subject_model == nil then
        return nil, 'InvalidArgument', string_format(
                'invalid subject: %s, not supported', api_ctx.subject)
    end
    api_ctx.subject_model = subject_model

    local action_model = subject_model['actions'][api_ctx.action]
    if action_model == nil then
        return nil, 'InvalidArgument', string_format(
                'subject: %s does not have action: %s',
                api_ctx.subject, api_ctx.action)
    end
    api_ctx.action_model = action_model

    return true, nil, nil
end


return _M
