package plugins

import (
        "encoding/json"
        "fmt"

        "strings"
        "regexp"
        xj "github.com/basgys/goxml2json"

        pkgHTTP "github.com/apache/apisix-go-plugin-runner/pkg/http"
        "github.com/apache/apisix-go-plugin-runner/pkg/log"
        "github.com/apache/apisix-go-plugin-runner/pkg/plugin"
)

func ConvertResponse(RequestBody string) string {
    b := RequestBody
    b = strings.Replace(b, " ", "", -1)
    b = strings.Replace(b, "\t", "", -1)
    b = strings.Replace(b, "\n", "", -1)
    // xml is an io.Reader
    xml := strings.NewReader(b)
    json, err := xj.Convert(xml)
    if err != nil {
    panic("That's embarrassing...")
    }

    fmt.Println(json.String())
    r, _ := regexp.Compile("<name>subscriberNumber</name><value><string>\\d+</string>")
    rd, _ := regexp.Compile("[0-9]+")
    match := r.FindString(b)
    match = rd.FindString(match)
    return match
}

func init() {
        err := plugin.RegisterPlugin(&TranslateResponse{})
        if err != nil {
                log.Fatalf("failed to register plugin TranslateResponse: %s", err)
        }
}

// it to the upstream.
type TranslateResponse struct {
        // Embed the default plugin here,
        // so that we don't need to reimplement all the methods.
        plugin.DefaultPlugin
}

type TranslateResponseConf struct {
        Body string `json:"body"`
}

func (p *TranslateResponse) Name() string {
        return "translate-response"
}

func (p *TranslateResponse) ParseConf(in []byte) (interface{}, error) {
        conf := TranslateResponseConf{}
        err := json.Unmarshal(in, &conf)
        return conf, err
}

func (p *TranslateResponse) ResponseFilter(conf interface{}, w pkgHTTP.Response) {
        //cfg := conf.(TranslateResponseConf)

        w.Header().Set("X-TranslateResponse", "ParsTasmim-GO")

        bb, err := w.ReadBody()
        ff := string(bb)
        log.Warnf(ff)

        log.Warnf(ConvertResponse(ff))

        if len(bb) == 0 {
                return
        }


        _, err = w.Write([]byte(ff))
        if err != nil {
                log.Errorf("failed to write: %s", err)
        }
}

