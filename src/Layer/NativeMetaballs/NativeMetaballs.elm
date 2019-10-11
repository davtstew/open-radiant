port module Layer.NativeMetaballs.NativeMetaballs exposing
    ( id
    , def
    , Model
    , Msg
    -- , PortModel
    , init
    , initial
    -- , export
    , view
    , defaultRange
    )


import Html as H
import Html.Attributes as H

import Json.Encode as E

import Math.Vector2 as Vec2 exposing (..)

import Random
import Random.Extra as Random exposing (traverse)

import Algorithm.Gaussian  as Gaussian exposing (Variety(..))
import Gradient exposing (Orientation(..))

import Model.Product as Product
import Model.Product exposing (ColorId(..))
import Model.Range exposing (..)
import Model.Layer.Blend.Html as Html exposing (Blend)
import Model.Layer.Blend.Html as Blend exposing (encode)
import Model.Layer.Broadcast as Broadcast exposing (Msg(..))
import Model.Layer.Def exposing (Index(..), indexToString)
import Model.Layer.Def as Layer exposing (Def, DefId, Kind(..))
import Model.Layer.Context exposing (Context)

import Layer.Fluid.Fluid as Fluid
import Layer.Fluid.Model as Fluid exposing
    ( Model
    , Orbit(..), Ranges
    , Randomization(..)
    )
import Layer.Fluid.Random as Fluid exposing
    ( generate, generator )
import Layer.Fluid.Export as FluidIE


id : DefId
id = "native-metaballs"


def : Layer.Def Model (H.Html Msg) Msg Html.Blend
def =
    { id = id
    , kind = JS
    , init = \_ ctx ->
        let
            model = init
        in
            ( model
            , generateInitial ctx
            )
    , encode = FluidIE.encode
    , decode = FluidIE.decode
    , subscribe = \_ _ -> Sub.none
    , update = update
    , response = response
    , view = view
    , gui = Nothing
    }



type Msg
    = Update Model -- called when random model was generated in any way
    | ChangeVariety Gaussian.Variety
    | ChangeOrbit Orbit
    | ChangeEffects Fluid.EffectsChange


type alias Model = Fluid.Model


type alias Orbit = Fluid.Orbit


update : Index -> Context -> Msg -> Model -> ( Model, Cmd Msg )
update (Index index) ctx msg model =
    case msg of
        Update newModel -> -- called when random model was generated in any way
            ( newModel
            , updateNativeMetaballs
                { index = index
                , size = ctx.size
                , palette = ctx.palette |> Product.encodePalette
                , layerModel = FluidIE.encode ctx newModel
                }
            )
        _ -> ( model, Cmd.none )


response : Index -> Context -> Broadcast.Msg -> Model -> ( Model, Cmd Msg )
response (Index index) ctx broadcastMsg model =
    case broadcastMsg of
        Broadcast.TurnOn ->
            ( model
            , updateNativeMetaballs
                { index = index -- index
                , size = ctx.size
                , palette = ctx.palette |> Product.encodePalette
                , layerModel = FluidIE.encode ctx model
                }
            )
        _ -> ( model, Cmd.none )


-- type alias PortModel =
--     { palette: Product.Palette
--     , temp : String
--     }

subscribe : Context -> Model -> Sub ( Layer.Index, Cmd Msg )
subscribe ctx model =
    Sub.batch
        [
        ]


init : Model
init =
    let fluidDefault = Fluid.init
    in
        { fluidDefault
        | variety = Variety 1000.0
        , orbit = Orbit 0.5
        }


-- export : Model -> PortModel
-- export model =
--     { palette = model.colors
--     , temp = ""
--     }


view : Index -> Context -> Maybe Html.Blend -> Model -> H.Html Msg
view index ctx maybeBlend model =
    H.canvas
        [ H.class "native-metaballs"
        , H.id <| "native-metaballs-" ++ indexToString index
        , H.style "mix-blend-mode" <|
            (maybeBlend
                |> Maybe.withDefault Blend.Normal
                |> Blend.encode)
        ]
        [] -- FIXME: use actual layer index


defaultRange : Fluid.Ranges
defaultRange =
    { groups = iRange 1 10
    , balls = iRange 4 50
    , radius = fRange 50 100
    , speed = fRange 150 250
    , phase = fRange 0 360 -- Maybe useless
    , amplitude =
        { x = fRange -30 30
        , y = fRange -10 10
        }
    }


groupOffset = { x = 0.65, y = 0.45 }


baseWidth = 1500


initial : ( Int, Int ) -> Fluid.StaticModel
initial ( w, h ) =
    { groups =
        [
            -- group 1
            { balls =
                [ { x = -50, y = 220,  radius = 50 }
                , { x = -20, y = 85,   radius = 90 }
                , { x = -30, y = 50,   radius = 60 }
                , { x = 170, y = 170,  radius = 100 }
                , { x = 370, y = 30,   radius = 40 }
                , { x = 450, y = 150,  radius = 50 }
                , { x = 270, y = -240, radius = 70 }
                , { x = 370, y = -130, radius = 60 }
                , { x = 170, y = -70,  radius = 70 }
                ]
            , gradient =
                [ { color = ColorIII, stop = 0.2 }
                , { color = ColorI,   stop = 0.3 }
                , { color = ColorII,  stop = 0.5 }
                , { color = ColorIII, stop = 0.8 }
                ]
            }
        ,
        -- group 2
            { balls =
                [ { x = 150, y = 350, radius = 30 }
                , { x = 250, y = 250, radius = 70 }
                , { x = 380, y = 280, radius = 30 }
                , { x = 200, y = 100, radius = 25 }
                ]
            , gradient =
                [ { color = ColorII,  stop = 0.2 }
                , { color = ColorIII, stop = 0.3 }
                , { color = ColorII,  stop = 0.5 }
                , { color = ColorIII, stop = 0.7 }
                ]
            }
        ,
        -- group 3
            { balls =
                [ { x = 410, y = -80,  radius = 28 }
                , { x = 340, y = -100, radius = 70 }
                , { x = 200, y = -150, radius = 40 }
                , { x = 250, y = -200, radius = 36 }
                ]
            , gradient =
                [ { color = ColorI,   stop = 0.5 }
                , { color = ColorII,  stop = 0.6 }
                , { color = ColorIII, stop = 0.7 }
                ]

            }
        ,
        -- group 4
            { balls =
                [ { x = -410, y = -270, radius = 48 }
                , { x = -490, y = -230, radius = 34 }
                , { x = -470, y = -320, radius = 40 }
                , { x = -700, y = 250,  radius = 30 }
                , { x = -740, y = 310,  radius = 20 }
                ]
            , gradient =
                [ { color = ColorIII, stop = 0.3 }
                , { color = ColorII,  stop = 0.4 }
                , { color = ColorII,  stop = 0.68 }
                , { color = ColorIII, stop = 0.77 }
                , { color = ColorIII, stop = 0.83 }
                ]
            }
        ,
        -- group 5
            { balls =
                [ { x = -830, y = 40,  radius = 30 }
                , { x = -700, y = 90,  radius = 60 }
                , { x = -540, y = 270, radius = 50 }
                , { x = -490, y = 150, radius = 90 }
                , { x = -300, y = 240, radius = 40 }
                , { x = -200, y = 120, radius = 35 }
                , { x = -350, y = 50,  radius = 70 }
                , { x = -490, y = -40, radius = 60 }
                , { x = -270, y = -70, radius = 50 }
                ]
            , gradient =
                [ { color = ColorIII, stop = 0.3 }
                , { color = ColorII,  stop = 0.5 }
                , { color = ColorI,   stop = 0.6 }
                ]
            }
        ,
        -- group 6
            { balls =
                [ { x = 26,   y = 55,   radius = 120 }
                , { x = -110, y = -90,  radius = 60 }
                , { x = 12,   y = -214, radius = 80 }
                , { x = -300, y = -80,  radius = 120 }
                , { x = -570, y = -120, radius = 50 }
                ]
            , gradient =
                [ { color = ColorI,   stop = 0.2 }
                , { color = ColorII,  stop = 0.35 }
                , { color = ColorIII, stop = 0.55 }
                , { color = ColorII,  stop = 0.75 }
                , { color = ColorI,   stop = 1.0 }
                ]
            }
        ] |> List.map
            (\group ->
                { balls =
                    group.balls
                        |> List.map
                            (\ball ->
                                { x = ball.x * (toFloat w / baseWidth)
                                , y = ball.y * (toFloat w / baseWidth)
                                , radius = ball.radius * (toFloat w / baseWidth)
                                }
                            )
                , gradient =
                    { stops =
                        group.gradient
                            |> List.map (\s -> ( s.stop, s.color ))
                    , orientation = Vertical
                    }
                , origin = groupOffset
                }
            )
    , effects = Fluid.defaultEffects
    }


generateInitial : Context -> Cmd Msg
generateInitial ctx =
    Fluid.generateInitial Update ctx <| initial ctx.size


generateDynamics : Context -> Model -> Cmd Msg
generateDynamics ctx model =
    Fluid.generateDynamics Update ctx model


generateStatics : Context -> Model -> Cmd Msg
generateStatics ctx model =
    Fluid.generateStatics Update ctx model


generateAll : Context -> Model -> Cmd Msg
generateAll ctx model =
    Fluid.generateAll Update ctx model


port updateNativeMetaballs :
    { index: Layer.JsIndex
    , size: (Int, Int)
    , layerModel : E.Value
    , palette: List String
    } -> Cmd msg
