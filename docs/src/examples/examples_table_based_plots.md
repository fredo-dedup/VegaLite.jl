# Table-based Plots

## Table Heatmap

```@example
using VegaLite, VegaDatasets

dataset("cars") |>
@vlplot(:rect, y=:Origin, x="Cylinders:o", color="mean(Horsepower)")
```

## Annual Weather Heatmap

```@example
using VegaLite, VegaDatasets

dataset("seattle-temps") |>
@vlplot(
    title="2010 Daily Max Temperature (F) in Seattle, WA",
    :rect,
    x={
        "date:o",
        timeUnit=:date,
        title="Day",
        axis={labelAngle=0,format="%e"}
    },
    y={
        "date:o",
        timeUnit=:month,
        title="Month"
    },
    color={
        "temp:q",
        aggregate="max",
        legend={title=nothing}
    },
    config={
        view={
            strokeWidth=0,
            step=13
        },
        axis={
            domain=false
        }
    }
)
```

## 2D Histogram Heatmap

```@example
using VegaLite, VegaDatasets

dataset("movies") |>
@vlplot(
    :rect,
    width=300, height=200,
    x={:IMDB_Rating, bin={maxbins=60}},
    y={:Rotten_Tomatoes_Rating, bin={maxbins=40}},
    color="count()",
    config={
        view={
            stroke="transparent"
        }
    }
)
```

## Table Bubble Plot (Github Punch Card)

```@example
using VegaLite, VegaDatasets

dataset("github") |>
@vlplot(
    :circle,
    y="day(time):o",
    x="hours(time):o",
    size="sum(count)"
)
```

## Layering text over heatmap

```@example
using VegaLite, VegaDatasets

cars = dataset("cars")

@vlplot(
    data=cars,
    y="Origin:o",
    x="Cylinders:o",
    config={
        scale={bandPaddingInner=0, bandPaddingOuter=0},
        text={baseline=:middle}
    }
) +
@vlplot(:rect, color="count()") +
@vlplot(
    :text,
    text="count()",
    color={
        condition={
            test="datum['count_*'] > 100",
            value=:black
        },
        value=:white
    }
)
```

## Lasagna Plot (Dense Time-Series Heatmap)

```@example
using VegaLite, VegaDatasets

dataset("stocks") |>
@vlplot(
    width=300,
    height=100,
    transform=[{filter="datum.symbol!=='GOOG'"}],
    mark=:rect,
    x={
        "date:o",
        timeUnit=:yearmonthdate,
        title="Time",
        axis={
            format="%Y",
            labelAngle=0,
            labelOverlap=false,
            labelColor={
                condition={
                    test={
                        field="value",
                        timeUnit=:monthdate,
                        equal={month=1,date=1}
                    },
                    value="black"
                },
                value=nothing
            },
            tickColor={
                condition={
                    test={
                        field="value",
                        timeUnit=:monthdate,
                        equal={month=1,date=1}
                    },
                    value="black"
                },
                value=nothing
            }
        }
    },
    y={
        "symbol:n",
        title=nothing
    },
    color={
        "price:q",
        aggregate="sum",
        title="Price"
    }
)
```

## Mosaic Chart with Labels

```@example
using VegaLite, VegaDatasets

dataset("cars") |>
@vlplot(
    resolve={scale={x="shared"}},
    config={
        view={stroke=""},
        concat={spacing=10},
        axis={
            domain=false,
            ticks=false,
            labels=false,
            grid=false
        }
    },
    transform=[
        {
            aggregate=[{op="count",as="count_*"}],
            groupby=["Origin","Cylinders"]
        },
        {
            stack="count_*",
            groupby=[],
            as=["stack_count_Origin1","stack_count_Origin2"],
            offset="normalize",
            sort=[{field="Origin",order="ascending"}]
        },
        {
            window=[
                {op="min",field="stack_count_Origin1",as="x"},
                {op="max",field="stack_count_Origin2",as="x2"},
                {op="dense_rank",as="rank_Cylinders"},
                {op="distinct",field="Cylinders",as="distinct_Cylinders"}
            ],
            groupby=["Origin"],
            frame=[nothing,nothing],
            sort=[{field="Cylinders",order="ascending"}]
        },
        {
            window=[
                {op="dense_rank",as="rank_Origin"}
            ],
            frame=[nothing,nothing],
            sort=[{field="Origin",order="ascending"}]
        },
        {
            stack="count_*",
            groupby=["Origin"],
            as=["y","y2"],
            offset="normalize",
            sort=[{field="Cylinders",order="ascending"}]
        },
        {calculate="datum.y + (datum.rank_Cylinders - 1) * datum.distinct_Cylinders * 0.01 / 3",as="ny"},
        {calculate="datum.y2 + (datum.rank_Cylinders - 1) * datum.distinct_Cylinders * 0.01 / 3",as="ny2"},
        {calculate="datum.x + (datum.rank_Origin - 1) * 0.01",as="nx"},
        {calculate="datum.x2 + (datum.rank_Origin - 1) * 0.01",as="nx2"},
        {calculate="(datum.nx+datum.nx2)/2",as="xc"},
        {calculate="(datum.ny+datum.ny2)/2",as="yc"},
    ]
) +
[
    @vlplot(
        mark={
            :text,
            baseline="middle",
            align="center"
        },
        x={
            "xc:q",
            aggregate="min",
            title="Origin",
            axis={orient=:top}
        },
        color={
            "Origin:n",
            legend=nothing
        },
        text="Origin:n"
    );
    (
        @vlplot() +
        @vlplot(
            :rect,
            x={"nx:q",axis=nothing},
            x2=:nx2,
            y={"ny:q",axis=nothing},
            y2=:ny2,
            color={"Origin:n",legend=nothing},
            opacity={field="Cylinders",type="quantitative",legend=nothing},
            tooltip=[{field="Origin",type="nominal"},{field="Cylinders",type="quantitative"}]
        ) +
        @vlplot(
            mark={:text,baseline="middle"},
            x={"xc:q",axis=nothing},
            y={"yc:q",axis={title="Cylinders"}},
            text="Cylinders:n"
        )
    )
]
```

## Wind Vector Map

```@example
using VegaLite, VegaDatasets

dataset("windvectors") |>
@vlplot(
    mark={:point, shape=:wedge},
    x={"longitude:o", axis=nothing},
    y={"latitude:o", axis=nothing},
    color={"dir:q", scale={domain=[0,360], scheme=:rainbow},legend=nothing},
    angle={"dir:q", scale={domain=[0,360], range=[180, 540]}},
    size="speed:q",
    config={view={step=10, fill=:black}}
)
```
