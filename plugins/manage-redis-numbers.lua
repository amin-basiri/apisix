local core = require("apisix.core")
local plugin = require("apisix.plugin")
local ngx = ngx
local s3_client = require "resty.aws_s3.client"
local cjson = require("cjson.safe")
local redis = require "resty.redis"


local plugin_name = "manage-redis-msisdns"

local backup_file_name = "backup.csv"


local schema = {}


local _M = {
    version = 0.5,
    priority = 13,
    name = plugin_name,
    schema = schema,
}

local redis_host = "redis"
local redis_port = 6379

local s3_bucket = "esb"
local s3_domain = "local-s3.mtnirancell.ir"
local s3_access_key = "OvWo9DV3FGw0QoAUJf3S"
local s3_secret_key = "pDmBE8CqZ8Z3LTxXkI8CnWzfcLZnPc4FSuE5psah"


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


local tz = require("tz")
-- local luatz = require("luatz")

local my_balance_request_body = '<?xml version="1.0" encoding="UTF-8"?><methodCall><methodName>GeneralGet</methodName><params><param><value><struct><member><name>originHostName</name><value><string>ESB</string></value></member><member><name>originTimeStamp</name><value><dateTime.iso8601>%s</dateTime.iso8601></value></member><member><name>originTransactionID</name><value><string>%s</string></value></member><member><name>requestDedicatedAccountInformationFlag</name><value><boolean>1</boolean></value></member><member><name>requestOfferInformationFlag</name><value><boolean>1</boolean></value></member><member><name>requestAccumulatorsFlag</name><value><boolean>1</boolean></value></member><member><name>negotiatedCapabilities</name><value><array><data><value><int>32832</int></value><value><int>65536</int></value></data></array></value></member><member><name>requestSubscriberInformationFlag</name><value><boolean>1</boolean></value></member><member><name>getUsageThresholdsAndCountersFlag</name><value><boolean>1</boolean></value></member><member><name>messageCapabilityFlag</name><value><struct><member><name>accountActivationFlag</name><value><boolean>1</boolean></value></member></struct></value></member><member><name>requestedInformationFlags</name><value><struct><member><name>requestMasterAccountBalanceFlag</name><value><boolean>1</boolean></value></member></struct></value></member><member><name>originNodeType</name><value><string>EXT</string></value></member><member><name>subscriberNumber</name><value><string>%s</string></value></member><member><name>externalData1</name><value><string>3</string></value></member><member><name>externalData2</name><value><string>0</string></value></member></struct></value></param></params></methodCall>'


local function create_my_balance_request(msisdn, referenceID)
    -- local now = luatz.time()
    -- local nowTimeTable = luatz.timetable.new_from_timestamp(now)
    -- local local_tz = luatz.get_tz("Asia/Tehran")
    -- local inputDate = nowTimeTable:strftime("%Y%m%dT%X%z")

    -- local now = luatz.time()
    -- local nowTimeTable = luatz.timetable.new_from_timestamp(now)
    
    -- local inputDate = nowTimeTable:strftime("%Y%m%dT%X%z")
    -- local inputDate = luatz.tzinfo("Asia/Tehran")

    local timestamp = os.time()
    local inputDate = tz.date("%Y-%m-%dT%H:%M:%S%z", timestamp, "Asia/Tehran")

    return inputDate
    -- TODO create inputDate
    -- inputDate = "20230909T12:28:31+0330"
    -- return string.format(my_balance_request_body, inputDate, referenceID, msisdn)
end




local function add_to_s3(msisdns)
    
    local client, err, msg = s3_client.new(s3_access_key, s3_secret_key, s3_domain)

    local resp, err, msg = client:put_object(
        {
            Bucket=s3_bucket,
            Key='backup',
            -- ACL='pub',
            -- ContentType='image/jpg',
            -- Metadata={
            --     foo1='bar1',
            --     foo2='bar2',
            -- },
            Body=cjson.encode(msisdns),  -- or use file name
            -- Body={file_path='path/to/my/file'}
        }
    )

    -- local resp, err, msg = client:get_object({Bucket=s3_bucket, Key='backup'})
    -- local file_content, err, msg = resp.Body.read(1024 * 1024)
    -- core.log.warn(('file content is: ' .. file_content))
    
    -- core.log.warn(msg)
    -- core.log.warn(err)
    -- core.log.warn(resp)

    return true
end


local function add_backup_file(msisdns)
    local backup_file = io.open(backup_file_name, "w+")

    -- core.log.warn("Heeeeeeeeeeeeeeeeeeeeey")
    if not backup_file then
        core.log.error("Where is the backup file?")
        return
    end
    -- core.log.warn("Hoooooooooooooooooooooo")
    for k,v in pairs(msisdns) do
        -- core.log.warn(k..","..v..'\n')
        backup_file:write(k..","..v..'\n')
    end

    io.close(backup_file)
end


local  function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
 end


local function dump_table(o)
if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump_table(v) .. ','
    end
    return s .. '} '
else
    return tostring(o)
end
end


local function delete_msisdn_from_backup_file(msisdns)

    -- Get file content
    local backup_file = io.open(backup_file_name, 'r')
    local backup_file_content = {}

    if not backup_file then
        core.log.error("Where is the backup file?")
        return false
    end

    for line in backup_file:lines() do
        table.insert(backup_file_content, line)
    end
    io.close(backup_file)


    -- Delete existing msisdns
    backup_file = io.open(backup_file_name, 'w')

    if not backup_file then
        core.log.error("Where is the backup file?")
        return false
    end

    
    for index, value in ipairs(backup_file_content) do
        local start_i, start_j = string.find(value, "9")
        local end_i, end_j = string.find(value, ",")

        local msisdn
        local state

        if end_i ~= nil and start_i ~= nil then
            state = string.sub(value, end_i + 1)
            state = state:gsub("%s+", "")
            state = string.gsub(state, "%s+", "")

            msisdn = string.sub(value, start_i, end_i - 1)
        end

        local is_deleted = msisdns[msisdn]
        
        if not is_deleted then
            backup_file:write(msisdn..","..state..'\n')
        end

    end

    io.close(backup_file)

    return true

end


local function update_backup_file_failed(msisdns)

    -- Add new file
    if not file_exists(backup_file_name) then
        add_backup_file(msisdns)
        return true
    end

    -- Set file content
    local lines = ""
    local backup_file = io.open(backup_file_name, 'r')

    if not backup_file then
        core.log.error("Where is the backup file?")
        return false
    end

    for line in backup_file:lines() do

        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        local msisdn
        local state

        if end_i ~= nil and start_i ~= nil then
            state = string.sub(line, end_i + 1)
            state = state:gsub("%s+", "")
            state = string.gsub(state, "%s+", "")

            msisdn = string.sub(line, start_i, end_i - 1)
        end

        local updated_state = msisdns[msisdn]
        
        msisdns[msisdn] = nil

        if not updated_state then
            updated_state = state
        end

        lines = lines .. msisdn .. "," .. updated_state .. '\n'
    end

    for k, v in pairs(msisdns) do
        lines = lines .. k .. "," .. v .. '\n'
    end

    io.close(backup_file)

    backup_file = io.open(backup_file_name, 'w')
    backup_file:write(lines)
    io.close(backup_file)

    return true

end


local function update_backup_file(msisdns)
    core.log.warn(ngx.ctx.api_ctx.resp_body)
    -- if add_to_s3(msisdns) then
    --     return
    -- end

    -- -- Add new file
    -- if not file_exists(backup_file_name) then
    --     add_backup_file(msisdns)
    --     return true
    -- end

    -- -- Set file content
    -- local backup_file = io.open(backup_file_name, 'r')
    -- -- local backup_file_content = {}

    -- if not backup_file then
    --     core.log.error("Where is the backup file?")
    --     return false
    -- end

    -- for line in backup_file:lines() do
    --     local start_i, start_j = string.find(line, "9")
    --     local end_i, end_j = string.find(line, ",")

    --     local msisdn
    --     local state

    --     if end_i ~= nil and start_i ~= nil then
    --         state = string.sub(line, end_i + 1)
    --         state = state:gsub("%s+", "")
    --         state = string.gsub(state, "%s+", "")

    --         msisdn = string.sub(line, start_i, end_i - 1)
    --     end

    --     if msisdns[msisdn] == nil then
    --         msisdns[msisdn] = state
    --     end

    -- end
    -- io.close(backup_file)


    -- -- Set msisdns
    -- -- for k, v in pairs(msisdns) do
    -- --     backup_file_content[k] = v
    -- -- end

    -- -- Update file
    -- backup_file = io.open(backup_file_name, 'w')

    -- if not backup_file then
    --     core.log.error("Where is the backup file?")
    --     return false
    -- end

    -- for k, v in pairs(msisdns) do
    --     backup_file:write(k..","..v..'\n')
    -- end
    -- io.close(backup_file)

    -- return true

end


local function update_backup_file_old_2(msisdns)

    -- Add new file
    if not file_exists(backup_file_name) then
        add_backup_file(msisdns)
        return true
    end

    -- Set file content
    local backup_file = io.open(backup_file_name, 'r')
    -- local backup_file_content = {}

    if not backup_file then
        core.log.error("Where is the backup file?")
        return false
    end

    for line in backup_file:lines() do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        local msisdn
        local state

        if end_i ~= nil and start_i ~= nil then
            state = string.sub(line, end_i + 1)
            state = state:gsub("%s+", "")
            state = string.gsub(state, "%s+", "")

            msisdn = string.sub(line, start_i, end_i - 1)
        end

        if msisdns[msisdn] == nil then
            msisdns[msisdn] = state
        end

    end
    io.close(backup_file)


    -- Set msisdns
    -- for k, v in pairs(msisdns) do
    --     backup_file_content[k] = v
    -- end

    -- Update file
    backup_file = io.open(backup_file_name, 'w')

    if not backup_file then
        core.log.error("Where is the backup file?")
        return false
    end

    for k, v in pairs(msisdns) do
        backup_file:write(k..","..v..'\n')
    end
    io.close(backup_file)

    return true

end


local function update_backup_file_old(msisdns)

    -- Add new file
    if not file_exists(backup_file_name) then
        -- core.log.warn("eeeeeeeeeeee")
        add_backup_file(msisdns)
        return true
    end

    
    -- core.log.warn("0000000000000000")


    -- Get file content
    local backup_file = io.open(backup_file_name, 'r')
    local backup_file_content = {}

    if not backup_file then
        core.log.error("Where is the backup file?")
        return false
    end

    for line in backup_file:lines() do
        table.insert(backup_file_content, line)
    end
    io.close(backup_file)

    -- core.log.warn(dump(backup_file_content))


    -- Set file content
    backup_file = io.open(backup_file_name, 'w')

    if not backup_file then
        core.log.error("Where is the backup file?")
        return false
    end

    -- Update existing msisdns
    for index, value in ipairs(backup_file_content) do
        local start_i, start_j = string.find(value, "9")
        local end_i, end_j = string.find(value, ",")

        local msisdn
        local state

        if end_i ~= nil and start_i ~= nil then
            state = string.sub(value, end_i + 1)
            state = state:gsub("%s+", "")
            state = string.gsub(state, "%s+", "")

            msisdn = string.sub(value, start_i, end_i - 1)
        end

        local updated_state = msisdns[msisdn]
        
        msisdns[msisdn] = nil

        -- core.log.warn("EEEE: "..updated_state)
        if not updated_state then
            updated_state = state
        end

        backup_file:write(msisdn..","..updated_state..'\n')

    end

    -- Add new msisdns
    for k,v in pairs(msisdns) do
        -- core.log.warn("Adding "..k)

        backup_file:write(k..","..v..'\n')
    end

    io.close(backup_file)

    return true

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

    local msisdns = {}

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
            
            msisdns[msisdn] = value

            redis_client:set(msisdn, value)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Add msisdns to redis failed"}
    end

    local ok, err = redis_client:close()

    local result = update_backup_file(msisdns)

    return 200, {msg='msisdns added'}
end


local function delete_msisdn_file(req_body)

    local redis_client, err = redis:new()

    local ok, err = redis_client:connect(redis_host, redis_port)
    if not ok then
        core.log.warn("failed to connect to redis: ", err)
        return 500, {msg="Redis connection failed"}
    end

    local msisdns = {}

    redis_client:init_pipeline()

    for line in string.gmatch(req_body,'[^\r\n]+') do
        local start_i, start_j = string.find(line, "9")
        local end_i, end_j = string.find(line, ",")

        if end_i ~= nil and start_i ~= nil then
            local msisdn = string.sub(line, start_i, end_i - 1)

            msisdns[msisdn] = "E"

            redis_client:del(msisdn)
        end
    end
    
    local ok, err = redis_client:commit_pipeline()
    if not ok then
        core.log.warn("failed to commit to pipeline: ", err)
        return 500, {msg="Delete msisdns from redis failed"}
    end

    local result = delete_msisdn_from_backup_file(msisdns)

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
            local result = create_my_balance_request()
            return 200, {msg=result}
            -- return get_msisdn(query_string)
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