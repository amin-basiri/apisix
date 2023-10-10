package plugins

import (
        "encoding/json"
        "net/http"
        "fmt"

        "strings"
        "regexp"
        xj "github.com/basgys/goxml2json"

        pkgHTTP "github.com/apache/apisix-go-plugin-runner/pkg/http"
        "github.com/apache/apisix-go-plugin-runner/pkg/log"
        "github.com/apache/apisix-go-plugin-runner/pkg/plugin"
)

func ExtractSubscriber(RequestBody string) string {
    b := RequestBody
    //b = strings.Replace(b, " ", "", -1)
    //b = strings.Replace(b, "\t", "", -1)
    //b = strings.Replace(b, "\n", "", -1)
    // xml is an io.Reader
    xml := strings.NewReader(b)
    json, err := xj.Convert(xml)
    if err != nil {
    panic("That's embarrassing...")
    }

    fmt.Println(json.String())
    r, _ := regexp.Compile("<name>subscriberNumber</name>\\s*<value>\\s*<string>\\d+</string>")
    rd, _ := regexp.Compile("[0-9]+")
    match := r.FindString(b)
    match = rd.FindString(match)
    return match
}

func init() {
        err := plugin.RegisterPlugin(&TranslateRequest{})
        if err != nil {
                log.Fatalf("failed to register plugin TranslateRequest: %s", err)
        }
}

// it to the upstream.
type TranslateRequest struct {
        // Embed the default plugin here,
        // so that we don't need to reimplement all the methods.
        plugin.DefaultPlugin
}

type TranslateRequestConf struct {
        Body string `json:"body"`
}

func (p *TranslateRequest) Name() string {
        return "translate-request"
}

func (p *TranslateRequest) ParseConf(in []byte) (interface{}, error) {
        conf := TranslateRequestConf{}
        err := json.Unmarshal(in, &conf)
        return conf, err
}

func (p *TranslateRequest) RequestFilter(conf interface{}, w http.ResponseWriter, r pkgHTTP.Request) {
        w.Header().Add("X-TranslateRequest", "ParsTasmim-GO")
        body := conf.(TranslateRequestConf).Body
        bb, _ := r.Body() // fmt.Sprintf("%+v", []byte(r.Body()))
        ff := string(bb)
        log.Warnf(ExtractSubscriber(ff))
        //fmt.Printf("%v\n", ff)
        return
        if len(body) == 0 {
                return
        }

        w.Header().Add("X-TranslateRequest", "ParsTasmim-GO")
        _, err := w.Write([]byte(body))
        if err != nil {
                log.Errorf("failed to write: %s", err)
        }
}


