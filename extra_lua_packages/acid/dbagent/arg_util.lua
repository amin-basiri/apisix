local arg_schema_checker = require('acid.arg_schema_checker')
local strutil = require('acid.strutil')
local tableutil = require('acid.tableutil')

local to_str = strutil.to_str
local string_format = string.format

local _M = {}


local function build_any_schema()
    local schema = {
        ['type'] = 'any',
    }

    return {schema}
end


local function build_string_schema()
    local schema = {
        ['type'] = 'string',
    }

    return {schema}
end


local function build_string_number_schema()
    local schema = {
        ['type'] = 'string_number',
    }

    return {schema}
end


local function build_integer_schema()
    local schema = {
        ['type'] = 'integer',
    }

    return {schema}
end


local function build_integer_or_string_number_schema()
    local schemas = {}
    tableutil.extends(schemas, build_integer_schema())
    tableutil.extends(schemas, build_string_number_schema())
    return schemas
end


local schema_builder = {
    binary = build_string_schema,
    varbinary = build_string_schema,
    varchar = build_string_schema,
    text = build_string_schema,
    tinyint = build_integer_or_string_number_schema,
    int = build_integer_or_string_number_schema,
    bigint = build_integer_or_string_number_schema,
}


function _M.build_field_schema(field)
    if field.convert_method ~= nil or field.range == true then
        field.checker = build_any_schema()
        return
    end

    local builder = schema_builder[field.data_type]

    if builder == nil then
        ngx.log(ngx.ERR, 'no schema builder for: ' .. field.data_type)
        return
    end

    field.checker = builder()

    for _, check in ipairs(field.checker) do
        tableutil.update(check, field.extra_check or {})
    end
end


function _M.set_default(api_ctx)
    local args = api_ctx.args
    local default = api_ctx.action_model.default

    if default == nil then
        return true, nil, nil
    end

    local setter = tableutil.default_setter(default)
    setter(args)

    return true, nil, nil
end


local function _schema_check(args, subject_model)
    for arg_name, arg_value in pairs(args) do
        local param_model = subject_model.fields[arg_name]

        if param_model ~= nil then
            local _, err, errmsg = arg_schema_checker.do_check(
                    arg_value, param_model.checker)
            if err ~= nil then
                return nil, 'InvalidArgument', string_format(
                        'failed to check schema of: %s, %s, %s, %s, %s',
                        arg_name, tostring(arg_value),
                        to_str(param_model.checker), err, errmsg)
            end
        end
    end

    return true, nil, nil
end


local function schema_check(args, subject_model)
    local _, err, errmsg = _schema_check(args, subject_model)
    if err ~= nil then
        return nil, err, errmsg
    end

    if args.match ~= nil then
        local _, err, errmsg = _schema_check(args.match, subject_model)
        if err ~= nil then
            return nil, err, errmsg
        end
    end

    return true, nil, nil
end


local function shape_check(args, subject_model, action_model)
    local args_copy = tableutil.dup(args, true)

    for _, allowed_params in pairs(action_model.param) do
        for param_name, required in pairs(allowed_params) do
            if required and args_copy[param_name] == nil then
                return nil, 'LackArgumet',
                        'lack argument: ' .. param_name
            end

            args_copy[param_name] = nil
        end
    end

    for arg_name, _ in pairs(args_copy) do
        if action_model.param.allowed_field == nil then
            if subject_model.fields[arg_name] == nil then
                return nil, 'ExtraArgument',
                        'extra argument: ' .. tostring(arg_name)
            end
        else
            return nil, 'ExtraArgument',
                    'extra argument: ' .. tostring(arg_name)
        end
    end

    return true, nil, nil
end


function _M.check(api_ctx)
    local args = api_ctx.args
    local subject_model = api_ctx.subject_model
    local action_model = api_ctx.action_model

    local _, err, errmsg = schema_check(args, subject_model)
    if err ~= nil then
        return nil, err, errmsg
    end

    local _, err, errmsg = shape_check(args, subject_model, action_model)
    if err ~= nil then
        return nil, err, errmsg
    end

    return true, nil, nil
end


return _M
