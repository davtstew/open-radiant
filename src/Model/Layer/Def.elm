module Model.Layer.Def exposing (..)

import Gui.Def exposing (Nest)

import Json.Decode as D
import Json.Encode as E

import Model.Layer.Blend.WebGL as WebGL


type Kind
    = Html
    | WebGL
    | Canvas
    | JS


type alias Def model view msg blend =
    { id : String
    , kind : Kind
    , init : model
    , encode : model -> E.Value
    , decode : D.Decoder model
    , update : msg -> model -> ( model, Cmd msg )
    , view : model -> Maybe blend -> view
    , subscribe : model -> Sub msg
    , gui : Maybe (model -> Nest msg)
    }


unit : Def () () () ()
unit =
    { id = "unit"
    , kind = JS
    , init = ()
    , encode = always <| E.object []
    , decode = D.succeed ()
    , update = \_ model -> ( model, Cmd.none )
    , subscribe = always Sub.none
    , view = always <| always ()
    , gui = Nothing
    }


-- kinda Either, but for ports:
--    ( Just WebGLBlend, Nothing ) --> WebGL Blend
--    ( Nothing, Just String ) --> HTML Blend
--    ( Nothing, Nothing ) --> None
--    ( Just WebGLBlend, Just String ) --> ¯\_(ツ)_/¯
type alias PortBlend =
    ( Maybe WebGL.Blend, Maybe String )


type alias PortDef =
    { def : String
    , kind : String
    , blend : PortBlend
    , visible : String
    , isOn : Bool
    , model : String
    }
