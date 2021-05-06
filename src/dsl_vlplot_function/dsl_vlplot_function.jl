struct VLFrag <: Vega.AbstractVegaFragment
    positional::Vector{Any}
    named::OrderedDict{String,Any}
end

function vlfrag(args...; kwargs...)
    return VLFrag(Any[args...], OrderedDict{String,Any}(string(k) => Vega.convert_nt_to_dict(v, VLFrag) for (k, v) in kwargs))
end

fix_shortcut_level_mark(spec_frag) = spec_frag

function fix_shortcut_level_mark(spec_frag::VLFrag)
    spec = copy(spec_frag.named)

    if length(spec_frag.positional) == 1
        spec["type"] = spec_frag.positional[1]
    elseif length(spec_frag.positional) > 1
        error("More than one positional element specified at the mark level.")
    end

    return VLFrag(Any[], spec)
end

fix_shortcut_level_encoding(name, spec_frag::Symbol, unnamed_inline_data) = VLFrag(Any[], OrderedDict{String,Any}("field" => string(spec_frag)))

fix_shortcut_level_encoding(name, spec_frag::String, unnamed_inline_data) = VLFrag(Any[], OrderedDict{String,Any}(parse_shortcut(spec_frag)...))

function fix_shortcut_level_encoding(name, spec_frag::AbstractVector, unnamed_inline_data)
    if !(name in ("tooltip", "detail", "order"))
        push!(unnamed_inline_data, Symbol(name) => spec_frag)
        return VLFrag(Any[], OrderedDict{String,Any}("field" => string(name), "title" => nothing))
    else
        return [fix_shortcut_level_encoding(name, i, unnamed_inline_data) for i in spec_frag]
    end
end

function fix_shortcut_level_encoding(name, spec_frag::VLFrag, unnamed_inline_data)
    spec = copy(spec_frag.named)

    if length(spec_frag.positional) == 1
        if spec_frag.positional[1] isa AbstractString || spec_frag.positional[1] isa Symbol
            new_frags = parse_shortcut(string(spec_frag.positional[1]))
            for (k, v) in new_frags
                spec[k] = v
            end
        elseif spec_frag.positional[1] isa AbstractVector && !(string(name) in ("tooltip", "detail", "order"))
            if haskey(spec, "field")
                error("The $name encoding channel cannot have inline data and a `field` element.")
            end
            push!(unnamed_inline_data, Symbol(name) => spec_frag.positional[1])
            spec["field"] = name
            if !haskey(spec, "title")
                spec["title"] = nothing
            end
        end
    elseif length(spec_frag.positional) > 1
        error("More than one positional element specified at the encoding level.")
    end

    return VLFrag(Any[], spec)
end

function fix_shortcut_level_data(spec_frag::VLFrag)
    if !isempty(spec_frag.positional)
        error("Positional arguments are invalid in data elements.")
    else
        if haskey(spec_frag.named, "url")
            spec = copy(spec_frag.named)

            if spec["url"] isa AbstractPath
                as_uri = string(URI(spec["url"]))
                spec["url"] = Sys.iswindows() ? as_uri[1:5] * as_uri[7:end] : as_uri
            elseif spec["url"] isa URI
                as_uri = string(spec["url"])
                spec["url"] = Sys.iswindows() && spec["url"].scheme == "file" ? as_uri[1:5] * as_uri[7:end] : as_uri
            end

            return VLFrag([], spec)
        else
            return spec_frag
        end
    end
end

function fix_shortcut_level_data(spec_frag::AbstractPath)
    as_uri = string(URI(spec_frag))
    return VLFrag([], OrderedDict{String,Any}("url" => Sys.iswindows() ? as_uri[1:5] * as_uri[7:end] : as_uri))
end

function fix_shortcut_level_data(spec_frag::URI)
    as_uri = string(spec_frag)
    return VLFrag([], OrderedDict{String,Any}("url" => Sys.iswindows() && spec_frag.scheme == "file" ? as_uri[1:5] * as_uri[7:end] : as_uri))
end

function fix_shortcut_level_data(spec_frag)
    if TableTraits.isiterabletable(spec_frag)
        it = IteratorInterfaceExtensions.getiterator(spec_frag)
        return VLFrag([], OrderedDict{String,Any}("values" => Vega.DataValuesNode(it)))
else
        return spec_frag
    end
end

function fix_shortcut_level_spec(spec_frag::VLFrag)
    spec = copy(spec_frag.named)

    if length(spec_frag.positional) > 0
    spec["mark"] = spec_frag.positional[1]
    elseif length(spec_frag.positional) > 3
        error("More than three positional element specified at the spec level.")
    end

    if haskey(spec, "enc")
        spec["encoding"] = spec["enc"]
        delete!(spec, "enc")
    end

    # Move top level channels into encoding
    encodings_to_be_moved = filter(
        i -> i != "facet",
        collect(keys(vlschema["definitions"]["FacetedEncoding"]["properties"])),
        )
    for k in collect(keys(spec))
        if string(k) in encodings_to_be_moved
            if !haskey(spec, "encoding")
                spec["encoding"] = VLFrag([], OrderedDict{String,Any}())
            end
            spec["encoding"].named[k] = spec[k]
            delete!(spec, k)
        elseif string(k) == "wrap"
            if !haskey(spec, "encoding")
                spec["encoding"] = VLFrag([], OrderedDict{String,Any}())
            end
            spec["encoding"].named["facet"] = spec[k]
            delete!(spec, k)
        end
    end

    if length(spec_frag.positional) in (2, 3)
        if !haskey(spec, "encoding")
            spec["encoding"] = VLFrag([], OrderedDict{String,Any}())
        end

        if haskey(spec["encoding"].named, "x")
            error("One cannot specify both a named and a positional argument for the `x` encoding channel.")
        end

        spec["encoding"].named["x"] = spec_frag.positional[2]
    end

    if length(spec_frag.positional) == 3
        if haskey(spec["encoding"].named, "y")
            error("One cannot specify both a named and a positional argument for the `y` encoding channel.")
        end

        spec["encoding"].named["y"] = spec_frag.positional[3]
    end

    if haskey(spec, "mark")
        spec["mark"] = fix_shortcut_level_mark(spec["mark"])
    end

    inline_unnamed_data = Pair{Symbol,AbstractVector}[]

    if haskey(spec, "encoding")
            if spec["encoding"] isa VLFrag
            if !isempty(spec["encoding"].positional)
                error("Can't have positional arguments inside the encoding element.")
            else
                spec["encoding"] = VLFrag([], OrderedDict{String,Any}(k => fix_shortcut_level_encoding(k, v, inline_unnamed_data) for (k, v) in spec["encoding"].named))
            end
        else
            spec["encoding"] = VLFrag([], OrderedDict{String,Any}(k => fix_shortcut_level_encoding(k, v, inline_unnamed_data) for (k, v) in spec["encoding"]))
        end
    end

    if haskey(spec, "transform")
        for transform in spec["transform"]
            if haskey(transform.named, "from") && haskey(transform.named["from"].named, "data")
                transform.named["from"].named["data"] = fix_shortcut_level_data(transform.named["from"].named["data"])
            end
        end
    end

    if haskey(spec, "data")
        if !isempty(inline_unnamed_data)
            error("Can't use a data element and specify inline data.")
        else
            spec["data"] = fix_shortcut_level_data(spec["data"])
        end
    elseif !isempty(inline_unnamed_data)
        if !all(isequal(length(inline_unnamed_data[1][2])), map(i -> length(i[2]), inline_unnamed_data))
            println(inline_unnamed_data)
            error("All columns must have the same length.")
        end
        spec["data"] = VLFrag([], OrderedDict{String,Any}("values" => Vega.DataValuesNode(TableTraitsUtils.create_tableiterator(map(i -> i[2], inline_unnamed_data), map(i -> i[1], inline_unnamed_data)))))
    end

    # Now fix child specs
    if haskey(spec, "spec")
        spec["spec"] = fix_shortcut_level_spec(spec["spec"])
    elseif haskey(spec, "layer")
        spec["layer"] = [fix_shortcut_level_spec(i) for i in spec["layer"]]
    elseif haskey(spec, "concat")
        spec["concat"] = [fix_shortcut_level_spec(i) for i in spec["concat"]]
    elseif haskey(spec, "vconcat")
        spec["vconcat"] = [fix_shortcut_level_spec(i) for i in spec["vconcat"]]
    elseif haskey(spec, "hconcat")
        spec["hconcat"] = [fix_shortcut_level_spec(i) for i in spec["hconcat"]]
    end

    return VLFrag([], spec)
end

function convert_frag_tree_to_dict(spec::VLFrag)
    # At this point all positional arguments should have been replaced
    # and we can convert everything into a plain Dict structure
    isempty(spec.positional) || error("There shouldn't be any positional argument left.")

    spec_as_dict = OrderedDict{String,Any}(k => Vega.replace_remaining_frag(v) for (k, v) in spec.named)

    spec_as_dict2 = Vega.walk_dict(spec_as_dict, "root") do p, parent
        if p[1] == "typ"
            Base.depwarn("`typ` in VegaLite.jl specs is deprecated, use `type` instead.", :vlplot)
        
            return "type" => p[2]
    else
            return p
end
    end

    return spec_as_dict2
end

function vlplot(args...;kwargs...)
    return VLSpec(convert_frag_tree_to_dict(fix_shortcut_level_spec(vlfrag(args...;kwargs...))))
end
