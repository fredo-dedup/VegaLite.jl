###############################################################################
#
#   Definition of VLSpec type and associated functions
#
###############################################################################

struct VLSpec <: Vega.AbstractVegaSpec
    params::OrderedDict
end

# data is an object in vega lite
function vl_set_spec_data!(specdict, datait)
    recs = [OrderedDict{String,Any}(string(c[1]) => isa(c[2], DataValues.DataValue) ? (isna(c[2]) ? nothing : get(c[2])) : c[2] for c in zip(keys(r), values(r))) for r in datait]
    specdict["data"] = OrderedDict{String,Any}("values" => recs)
end

function augment_encoding_type(x::AbstractDict, data::Vega.DataValuesNode)
    if !haskey(x, "type") && !haskey(x, "aggregate") && haskey(x, "field") && haskey(data.columns, Symbol(x["field"]))
        new_x = copy(x)
        
        jl_type = eltype(data.columns[Symbol(x["field"])])
        
        if jl_type <: DataValues.DataValue
            jl_type = eltype(jl_type)
        end
        
        if jl_type <: Number
            new_x["type"] = "quantitative"
        elseif jl_type <: AbstractString
            new_x["type"] = "nominal"
        elseif jl_type <: Dates.AbstractTime
            new_x["type"] = "temporal"
        end
        
        return new_x
    else
    return x
end
end

function add_encoding_types(specdict, parentdata=nothing)
    if (haskey(specdict, "data") && haskey(specdict["data"], "values") && specdict["data"]["values"] isa Vega.DataValuesNode) || parentdata !== nothing       
        data = (haskey(specdict, "data") && haskey(specdict["data"], "values") && specdict["data"]["values"] isa Vega.DataValuesNode) ? specdict["data"]["values"] : parentdata

        newspec = OrderedDict{String,Any}(
            (k == "encoding" && v isa AbstractDict) ? k => OrderedDict{String,Any}(kk => augment_encoding_type(vv, data) for (kk, vv) in v) : 
                k == "spec" ? k => add_encoding_types(v, data) :
                k in ("layer", "concat", "vconcat", "hconcat") ? k => [add_encoding_types(i, data) for i in v] : k => v for (k, v) in specdict
        )

        return newspec
    else
        return specdict
    end
end

function our_json_print(io, spec::VLSpec)
    JSON.print(io, add_encoding_types(Vega.getparams(spec)))
end

function (p::VLSpec)(data)
    TableTraits.isiterabletable(data) || throw(ArgumentError("'data' is not a table."))  
    
    it = IteratorInterfaceExtensions.getiterator(data)

    datavaluesnode = Vega.DataValuesNode(it)

    new_dict = copy(Vega.getparams(p))

    new_dict["data"] = OrderedDict{String,Any}("values" => datavaluesnode)

    return VLSpec(new_dict)
    end

function (p::VLSpec)(uri::URI)
    new_dict = copy(Vega.getparams(p))
    new_dict["data"] = OrderedDict{String,Any}("url" => string(uri))

    return VLSpec(new_dict)
end

function (p::VLSpec)(path::AbstractPath)
    new_dict = copy(Vega.getparams(p))

    as_uri = string(URI(path))

    # TODO This is a hack that might only work on Windows
    # Vega seems to not understand properly formed file URIs
    new_dict["data"] = OrderedDict{String,Any}("url" => Sys.iswindows() ? as_uri[1:5] * as_uri[7:end] : as_uri)

    return VLSpec(new_dict)
end

Base.:(==)(x::VLSpec, y::VLSpec) = Vega.getparams(x) == Vega.getparams(y)

"""
    Vega.deletedata!(spec::VLSpec)

Delete data from `spec` in-place.  See also [`Vega.deletedata`](@ref).
"""
function Vega.deletedata!(spec::VLSpec)
    delete!(Vega.getparams(spec), "data")
    return spec
end

"""
    Vega.deletedata(spec::VLSpec)

Create a copy of `spec` without data.  See also [`Vega.deletedata!`](@ref).
"""
Vega.deletedata(spec::VLSpec) = Vega.deletedata!(copy(spec))

function Base.:+(a::VLSpec, b::VLSpec)
    new_spec = deepcopy(Vega.getparams(a))
    if haskey(new_spec, "facet") || haskey(new_spec, "repeat")
        new_spec["spec"] = deepcopy(Vega.getparams(b))
    elseif haskey(Vega.getparams(b), "vconcat")
        new_spec["vconcat"] = deepcopy(Vega.getparams(b)["vconcat"])
    elseif haskey(Vega.getparams(b), "hconcat")
        new_spec["hconcat"] = deepcopy(Vega.getparams(b)["hconcat"])
    else
        if !haskey(new_spec, "layer")
            new_spec["layer"] = []
        end
        push!(new_spec["layer"], deepcopy(Vega.getparams(b)))
    end

    return VLSpec(new_spec)
end

function Base.hcat(A::VLSpec...)
    spec = VLSpec(OrderedDict{String,Any}())
    Vega.getparams(spec)["hconcat"] = []
    for i in A
        push!(Vega.getparams(spec)["hconcat"], deepcopy(Vega.getparams(i)))
    end
    return spec
end

function Base.vcat(A::VLSpec...)
  spec = VLSpec(OrderedDict{String,Any}())
  Vega.getparams(spec)["vconcat"] = []
  for i in A
      push!(Vega.getparams(spec)["vconcat"], deepcopy(Vega.getparams(i)))
  end
  return spec
end
