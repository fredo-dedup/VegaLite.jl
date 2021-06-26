function _convert_vl_with_cmds(v::VLSpec, cmds...)
    in_buf = IOBuffer()
    our_json_print(in_buf, v)
    seekstart(in_buf)

    p = open(pipeline(in_buf, cmds...))
    reader = @async read(p, String)
    wait(p)

    if any(proc -> proc.exitcode != 0, p.processes)
        # Is "Invalid spec" the only possible cause of failure?
        throw(ArgumentError("Invalid spec"))
    end

    res = fetch(reader)

    return res
end

function convert_vl_to_vg(v::VLSpec)
    vl2vg_script_path = joinpath(vegaliate_app_path, "vl2vg.js")
    return _convert_vl_with_cmds(
        v,
        Cmd(`$(nodejs_cmd()) $vl2vg_script_path`, dir=vegaliate_app_path),
    )
end

function convert_vl_to_x(v::VLSpec, second_script)
    vl2vg_script_path = joinpath(vegaliate_app_path, "vl2vg.js")
    full_second_script_path =
        joinpath(vegaliate_app_path, "node_modules", "vega-cli", "bin", second_script)

    njscmd = nodejs_cmd()
    return _convert_vl_with_cmds(
        v,
        Cmd(`$njscmd $vl2vg_script_path`, dir=vegaliate_app_path),
        Cmd(`$njscmd $full_second_script_path -l error`, dir=vegaliate_app_path),
    )
end

function convert_vl_to_svg(v::VLSpec)
    vl2vg_script_path = joinpath(vegaliate_app_path, "vl2vg.js")
    vg2svg_script_path = joinpath(vegaliate_app_path, "vg2svg.js")

    njscmd = nodejs_cmd()
    return _convert_vl_with_cmds(
        v,
        Cmd(`$njscmd $vl2vg_script_path`, dir=vegaliate_app_path),
        Cmd(`$njscmd $vg2svg_script_path`, dir=vegaliate_app_path),
    )
end

Base.Multimedia.istextmime(::MIME{Symbol("application/vnd.vegalite.v4+json")}) = true

function Base.show(io::IO, m::MIME"application/vnd.vegalite.v4+json", v::VLSpec)
    our_json_print(io, v)
end

function Base.show(io::IO, m::MIME"application/vnd.vega.v5+json", v::VLSpec)
    print(io, convert_vl_to_vg(v))
end

function Base.show(io::IO, m::MIME"image/svg+xml", v::VLSpec)
    print(io, convert_vl_to_svg(v))
end

function Base.show(io::IO, m::MIME"application/pdf", v::VLSpec)
    if vegaliate_app_includes_canvas
        print(io, convert_vl_to_x(v, "vg2pdf"))
    else
        error("Not yet implemented.")
        # svgstring = convert_vl_to_svg(v)

        # r = Rsvg.handle_new_from_data(svgstring)
        # d = Rsvg.handle_get_dimensions(r)

        # cs = Cairo.CairoPDFSurface(io, d.width,d.height)
        # try
        #     c = Cairo.CairoContext(cs)
        #     Rsvg.handle_render_cairo(c,r)
        # finally
        #     Cairo.finish(cs)
        # end
    end
end

# function Base.show(io::IO, m::MIME"application/eps", v::VLSpec)
#     svgstring = convert_vl_to_svg(v)

#     r = Rsvg.handle_new_from_data(svgstring)
#     d = Rsvg.handle_get_dimensions(r)

#     cs = Cairo.CairoEPSSurface(io, d.width,d.height)
#     try
#         c = Cairo.CairoContext(cs)
#         Rsvg.handle_render_cairo(c,r)
#     finally
#         Cairo.finish(cs)
#     end
# end

function Base.show(io::IO, m::MIME"image/png", v::VLSpec)
    if vegaliate_app_includes_canvas
        print(io, convert_vl_to_x(v, "vg2png"))
    else
        error("Not yet implemented.")
        # svgstring = convert_vl_to_svg(v)

        # r = Rsvg.handle_new_from_data(svgstring)
        # d = Rsvg.handle_get_dimensions(r)

        # cs = Cairo.CairoImageSurface(d.width,d.height,Cairo.FORMAT_ARGB32)
        # c = Cairo.CairoContext(cs)
        # Rsvg.handle_render_cairo(c,r)
        # Cairo.write_to_png(cs,io)
    end
end

function Base.show(io::IO, m::MIME"application/vnd.julia.fileio.htmlfile", v::VLSpec)
    writehtml_full(io, v)
end

function Base.show(io::IO, m::MIME"application/prs.juno.plotpane+html", v::VLSpec)
    writehtml_full(io, v)
end

Base.showable(m::MIME"text/html", v::VLSpec) = isdefined(Main, :PlutoRunner)
function Base.show(io::IO, m::MIME"text/html", v::VLSpec)
    writehtml_partial_script(io, v)
end
