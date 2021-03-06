module TronGui exposing (gui)

import Dict as Dict

import Gui.Gui as Gui
import Gui.Def exposing (..)
import Gui.Nest exposing (..)

import Model.AppMode exposing (AppMode(..))
import Model.Core as Core exposing (..)
import Model.Product as Product exposing (Product(..))
import Model.SizeRule exposing (..)
import Model.Layer.Layer as Layer exposing (Model(..), getModel)
import Model.Layer.Def as Layer exposing (Index)
import Model.Layer.Blend.Html as HtmlBlend
import Model.Layer.Blend.WebGL as WGLBlend


gui : Core.Model -> Gui.Model Core.Msg
gui from =
    let
        ( currentSizePresets, sizePresetsShape ) =
            ( getSizePresets from.mode
                |> List.map (\preset -> ( getPresetLabel preset, getPresetSize preset ))
                |> Dict.fromList
            , case from.mode of
                Release -> ( 4, 4 )
                Ads -> ( 8, 4 )
                _ -> ( 4, 2 )
            )
        products =
            [ "jetbrains"
            , "idea"
            , "phpstorm"
            , "pycharm"
            , "rubymine"
            , "webstorm"
            , "clion"
            , "datagrip"
            , "appcode"
            , "goland"
            , "rs"
            , "rs cpp"
            , "dotcover"
            , "dotmemory"
            , "dotpeek"
            , "dottrace"
            , "rider"
            , "teamcity"
            , "youtrack"
            , "upsource"
            , "hub"
            , "kotlin"
            , "mps"
            -- TODO
            ]
        htmlBlends =
            [ "normal"
            , "overlay"
            , "multiply"
            , "darken"
            , "lighten"
            , "multiply"
            , "multiply"
            , "multiply"
            , "multiply"
            ]
        productsGrid =
            products
                |> List.map ChoiceItem
                |> nestWithin ( 6, 4 )
        sizeGrid =
            ( "browser" :: Dict.keys currentSizePresets )
                |> List.map ChoiceItem
                |> nestWithin sizePresetsShape
        htmlBlendGrid =
            htmlBlends
                |> List.map ChoiceItem
                |> nestWithin ( 3, 3 )
        htmlControls currentBlend layerIndex =
            oneLine
                [ Toggle "visible" TurnedOn <| toggleVisibility layerIndex
                , Choice "blend" Collapsed 0 (chooseHtmlBlend layerIndex) htmlBlendGrid
                ]
        chooseProduct _ label =
            case label of
                "rs" -> ChangeProduct Product.ReSharper
                "rs cpp" -> ChangeProduct Product.ReSharperCpp
                "idea" -> ChangeProduct Product.IntelliJ
                _ -> Product.decode label
                        |> Result.withDefault Product.default
                        |> ChangeProduct
        chooseSize _ label =
            case label of
                "window" -> RequestFitToWindow
                "browser" -> RequestFitToWindow
                _ ->
                    currentSizePresets -- FIXME: use proper size sets
                        |> Dict.get label
                        |> Maybe.map (\(w, h) -> Resize <| UseViewport <| ViewportSize w h)
                        |> Maybe.withDefault RequestFitToWindow
        chooseWebGlBlend layerIndex index label =
            NoOp
        chooseHtmlBlend layerIndex _ label =
            ChangeHtmlBlend layerIndex <| HtmlBlend.decode label
        toggleVisibility layerIndex state =
            layerIndex |> if (state == TurnedOn) then TurnOn else TurnOff
        rotateKnobSetup =
            { min = -1.0, max = 1.0, step = 0.05, roundBy = 100
            , default = from.omega }
        layerButtons =
            from.layers
                |> List.filter
                    (\layer ->
                        case ( Layer.getModel layer, from.mode ) of
                            ( Cover _, Production ) -> False
                            _ -> True
                    )
                |> List.indexedMap
                    (\layerIndex _ ->
                        Ghost <| "layer " ++ String.fromInt layerIndex
                        {- FIXME: return back
                        case layer of
                            WebGLLayer webGllayer webglBlend ->
                                case model of
                                    FssModel fssModel ->
                                        Nested (String.toLower name) Collapsed
                                            <| fssControls from.mode fssModel webglBlend layerIndex
                                    _ -> Ghost <| "layer " ++ String.fromInt layerIndex
                            HtmlLayer _ htmlBlend ->
                                Nested (String.toLower name) Collapsed
                                    <| htmlControls htmlBlend layerIndex
                        -}
                    )
    in
        Gui.build <|
            oneLine <|
                [ Choice "product" Collapsed 0 chooseProduct productsGrid
                , Knob "rotation" rotateKnobSetup from.omega Rotate
                , Choice "size" Collapsed 0 chooseSize sizeGrid
                -- , Button "save png" <| always SavePng
                , Button "lucky" <| always Randomize
                ]
                ++ layerButtons



webglBlendGrid : AppMode -> WGLBlend.Blend -> Layer.Index -> Nest Core.Msg
webglBlendGrid mode currentBlend layerIndex =
    let
        blendFuncs =
            [ "+", "-", "R-" ]
        blendFactors =
            [ "0", "1"
            , "sC", "1-sC"
            , "dC", "1-dC"
            , "sα", "1-sα"
            , "dα", "1-dα"
            , "αS"
            , "CC", "1-CC"
            , "Cα", "1-Cα"
            ]
        funcGrid =
            blendFuncs
                |> List.map ChoiceItem
                |> nestWithin ( 3, 1 )
        factorGrid =
            blendFactors
                |> List.map ChoiceItem
                |> nestWithin ( 8, 2 )
        chooseBlendColorFn index label =
            AlterWGLBlend layerIndex
                (\curBlend ->
                    let ( _, colorFactor1, colorFactor2 ) = curBlend.colorEq
                    in { curBlend | colorEq =
                        ( WGLBlend.decodeFunc label, colorFactor1, colorFactor2 ) }
                )
        chooseBlendColorFact1 index label =
            AlterWGLBlend layerIndex
                (\curBlend ->
                    let ( colorFunc, _, colorFactor2 ) = curBlend.colorEq
                    in { curBlend | colorEq =
                        ( colorFunc, WGLBlend.decodeFactor label, colorFactor2 ) }
                )
        chooseBlendColorFact2 index label =
            AlterWGLBlend layerIndex
                (\curBlend ->
                    let ( colorFunc, colorFactor1, _ ) = curBlend.colorEq
                    in { curBlend | colorEq =
                        ( colorFunc, colorFactor1, WGLBlend.decodeFactor label ) }
                )
        chooseBlendAlphaFn index label =
            AlterWGLBlend layerIndex
                (\curBlend ->
                    let ( _, alphaFactor1, alphaFactor2 ) = curBlend.alphaEq
                    in { curBlend | alphaEq =
                        ( WGLBlend.decodeFunc label, alphaFactor1, alphaFactor2 ) }
                )
        chooseBlendAlphaFact1 index label =
            AlterWGLBlend layerIndex
                (\curBlend ->
                    let ( alphaFunc, alphaFactor1, _ ) = curBlend.alphaEq
                    in { curBlend | alphaEq =
                        ( alphaFunc, alphaFactor1, WGLBlend.decodeFactor label )
                    }
                )
        chooseBlendAlphaFact2 index label =
            AlterWGLBlend layerIndex
                (\curBlend ->
                    let ( alphaFunc, _, alphaFactor2 ) = curBlend.alphaEq
                    in { curBlend | alphaEq =
                        ( alphaFunc, WGLBlend.decodeFactor label, alphaFactor2 )
                    }
                )
    in
        nestWithin ( 3, 2 )
        -- TODO color
            [ Choice "colorFn"  Collapsed 0 chooseBlendColorFn funcGrid
            , Choice "colorFt1" Collapsed 1 chooseBlendColorFact1 factorGrid
            , Choice "colorFt2" Collapsed 0 chooseBlendColorFact2 factorGrid
            , Choice "alphaFn"  Collapsed 0 chooseBlendAlphaFn funcGrid
            , Choice "alphaFt1" Collapsed 1 chooseBlendAlphaFact1 factorGrid
            , Choice "alphaFt2" Collapsed 0 chooseBlendAlphaFact2 factorGrid
            ]




