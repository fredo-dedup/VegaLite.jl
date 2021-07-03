using Test
using VegaLite
using URIParser
using FilePaths
using DataFrames
using VegaDatasets

@testset "Spec" begin

@test @vlplot()(URI("http://www.foo.com/bar.json")) == vl"""
    {
        "data": {
            "url": "http://www.foo.com/bar.json"
        }
    }
    """

@test_throws ArgumentError @vlplot()(5)

df = DataFrame(a=[1.,2.], b=["A", "B"], c=[Date(2000), Date(2001)])

p1 = (df |> @vlplot("line", x = :c, y = :a, color = :b))
p2 = vl"""
{
  "encoding": {
    "x": {
      "field": "c"
    },
    "color": {
      "field": "b"
    },
    "y": {
      "field": "a"
    }
  },
  "mark": "line"
}
"""

p3 = Vega.deletedata(p1)
@test p3 != p1
@test p3 == p2

Vega.deletedata!(p1)

@test p1 == p2

p3 = DataFrame(a=[1,2,missing], b=[3.,2.,1.]) |> @vlplot(:point, x = :a, y = :b)

p4 = vl"""
{
  "encoding": {
    "x": {
      "field": "a",
      "type": "quantitative"
    },
    "y": {
      "field": "b",
      "type": "quantitative"
    }
  },
  "data": {
    "values": [
      {
        "b": 3.0,
        "a": 1
      },
      {
        "b": 2.0,
        "a": 2
      },
      {
        "b": 1.0,
        "a": null
      }
    ]
  },
  "mark": "point"
}
"""

# @test p3 == p4

p5 = dataset("cars").path |> @vlplot(:point, x = :Miles_per_Gallon, y = :Acceleration)

@test haskey(Vega.getparams(p5)["data"], "url")

end

@testset "Array tooltip data" begin
  p10 = dataset("cars")|> @vlplot(:point,x=:Horsepower,y=:Miles_per_Gallon,tooltip=[:Horsepower,"Miles_per_Gallon:q"])
  @test isa(p10.encoding.tooltip, Vector)
end
