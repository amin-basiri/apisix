# Separated APIs


### Call Add

```shell
curl -i -X POST "http://127.0.0.1:9080/add_number" -H "Host: example.com" -d '{"number": "9911339329"}' -H 'Content-Type: application/json'
```


### Call Add Batch

```shell
curl -i -X POST "http://127.0.0.1:9080/add_number_batch" -H "Host: example.com" -d '09011337323,09011337324,09011337325' -H 'Content-Type: application/json'
```


### Call Add File

```shell
curl -i -X POST "http://127.0.0.1:9080/add_number_file" -H "Host: example.com" -F numbers=@numbers.csv 
```



### Call Del

```shell
curl -i -X POST "http://127.0.0.1:9080/del_number" -H "Host: example.com" -d '{"number": "9911339329"}' -H 'Content-Type: application/json'
```


### Call Del Batch

```shell
curl -i -X POST "http://127.0.0.1:9080/del_number_batch" -H "Host: example.com" -d '09011337323,09011337324,09011337325' -H 'Content-Type: application/json'
```



### Call Del File

```shell
curl -i -X POST "http://127.0.0.1:9080/del_number_file" -H "Host: example.com" -F numbers=@numbers.csv 
```

----------------------------------------------------------------------------------


# Manage Redis Numbers

### Add One Number

```shell
curl -i -X POST "http://127.0.0.1:9080/manage_redis_numbers?type=normal" -H "Host: example.com" -d '9011337323'
```

### Get One Number

```shell
curl -i -X GET "http://127.0.0.1:9080/manage_redis_numbers?type=normal&number=9011337323" -H "Host: example.com"
```

### Delete One Number

```shell
curl -i -X DELETE "http://127.0.0.1:9080/manage_redis_numbers?type=normal&number=9011337323" -H "Host: example.com"
```