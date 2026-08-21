module InProc
export create_inproc_responder
import JuliaWebAPI: InProcTransport, DictMsgFormat, APIResponder, register

function _add_spec(spec::Tuple, api::APIResponder)
    fn = spec[1]
    resp_json = (length(spec) > 1) ? spec[2] : false
    resp_hdrs = (length(spec) > 2) ? spec[3] : Dict{String,String}()
    apif_name = (length(spec) > 3) ? spec[4] : default_endpoint(fn)
    register(api, fn; resp_json=resp_json, resp_headers=resp_hdrs, endpt=apif_name)
end

function default_endpoint(f::Function)
    endpt = string(f)
    # separate the module (more natural URL, assumes 'using Module')
    if '.' in endpt
        endpt = rsplit(endpt, '.'; limit=2)[2]
    end
    endpt
end

function create_inproc_responder(
    apispecs::Array,
    addr::Symbol
)::APIResponder{InProcTransport,DictMsgFormat}
    api = APIResponder(InProcTransport(addr), DictMsgFormat())
    for spec in apispecs
        _add_spec(spec, api)
    end
    api
end
end # module InProc
