module Gui.Gui exposing
    ( Msg, Model
    , view, update, build
    , moves, ups, downs
    )


import Gui.Cell exposing (..)
import Gui.Nest exposing (..)
import Gui.Grid exposing (..)
import Gui.Mouse exposing (..)


type alias Model umsg = ( MouseState, Nest umsg )
type alias View umsg = Grid umsg
type alias Msg umsg = Gui.Cell.Msg umsg


view = Tuple.second >> Gui.Grid.view
moves = Gui.Mouse.moves
ups = Gui.Mouse.ups >> TrackMouse
downs = Gui.Mouse.downs >> TrackMouse


build : Nest umsg -> Model umsg
build nest =
    ( Gui.Mouse.init, nest )


subscriptions : Model umsg -> Sub (Msg umsg)
subscriptions model = Sub.batch []


update
    : (umsg -> umodel -> ( umodel, Cmd umsg ))
    -> umodel
    -> Msg umsg
    -> Model umsg
    -> ( ( umodel, Cmd umsg ), Model umsg )
update userUpdate userModel msg (( mouse, ui ) as model) =
    case msg of
        TrackMouse mouse ->
            ( userModel ! []
            , ui |> withMouse mouse
            )
        Tune pos value ->
            ( userModel ! []
            , ui
                |> shiftFocusTo pos
                |> updateCell pos
                    (\cell ->
                        case cell of
                            Knob label setup  _ ->
                                -- TODO: use min, max, step
                                Knob label setup value
                            _ -> cell
                    )
                |> withMouse mouse
            )
        ToggleOn pos ->
            ( userModel ! []
            , ui
                |> shiftFocusTo pos
                |> updateCell pos
                    (\cell ->
                        case cell of
                            Toggle label _ handler ->
                                Toggle label TurnedOn handler
                            _ -> cell
                    )
                |> withMouse mouse
            )
        ToggleOff pos ->
            ( userModel ! []
            , ui
                |> shiftFocusTo pos
                |> updateCell pos
                    (\cell ->
                        case cell of
                            Toggle label _ handler ->
                                Toggle label TurnedOff handler
                            _ -> cell
                    )
                |> withMouse mouse
            )
        ExpandNested pos ->
            ( userModel ! []
            , ui
                |> shiftFocusTo pos
                |> collapseAllAbove pos
                |> updateCell pos
                    (\cell ->
                        case cell of
                            Nested label _ cells ->
                                Nested label Expanded cells
                            _ -> cell
                    )
                |> withMouse mouse
            )
        CollapseNested pos ->
            ( userModel ! []
            , ui
                |> shiftFocusTo pos
                |> updateCell pos
                    (\cell ->
                        case cell of
                            Nested label _ cells ->
                                Nested label Collapsed cells
                            _ -> cell
                    )
                |> withMouse mouse
            )
        ExpandChoice pos ->
            ( userModel ! []
            , ui
                |> collapseAllAbove pos
                |> shiftFocusTo pos
                |> updateCell pos
                    (\cell ->
                        case cell of
                            Choice label _ selection handler cells ->
                                Choice label Expanded selection handler cells
                            _ -> cell
                    )
                |> withMouse mouse
            )
        CollapseChoice pos ->
            ( userModel ! []
            , ui
                |> shiftFocusTo pos
                |> updateCell pos
                    (\cell ->
                        case cell of
                            Choice label _ selection handler cells ->
                                Choice label Collapsed selection handler cells
                            _ -> cell
                    )
                |> withMouse mouse
            )
        Select pos ->
            ( userModel ! []
            , let
                parentPos = getParentPos pos |> Maybe.withDefault nowhere
                index = getIndexOf pos |> Maybe.withDefault -1
            in
                ui
                    |> shiftFocusTo pos
                    |> updateCell parentPos
                        (\cell ->
                            case cell of
                                Choice label expanded selection handler cells ->
                                    Choice label expanded index handler cells
                                _ -> cell
                        )
                    |> withMouse mouse
            )

        SendToUser userMsg -> ( userUpdate userMsg userModel, ui |> withMouse mouse )

        SelectAndSendToUser pos userMsg ->
            sequenceUpdate userUpdate userModel
                [ Select pos, SendToUser userMsg ]
                ( ui |> withMouse mouse )

        ToggleOnAndSendToUser pos userMsg ->
            sequenceUpdate userUpdate userModel
                [ ToggleOn pos, SendToUser userMsg ]
                ( ui |> withMouse mouse )

        ToggleOffAndSendToUser pos userMsg ->
            sequenceUpdate userUpdate userModel
                [ ToggleOff pos, SendToUser userMsg ]
                ( ui |> withMouse mouse )

        ShiftFocusLeftAt pos ->
            ( userModel ! [], ui |> shiftFocusBy -1 pos |> withMouse mouse )

        ShiftFocusRightAt pos ->
            ( userModel ! [], ui |> shiftFocusBy 1 pos |> withMouse mouse )

        NoOp -> ( userModel ! [], ui |> withMouse mouse )


withMouse : MouseState -> Nest umsg -> Model umsg
withMouse = (,)


sequenceUpdate
    : (umsg -> umodel -> ( umodel, Cmd umsg ))
    -> umodel
    -> List (Msg umsg)
    -> Model umsg
    -> ( ( umodel, Cmd umsg ), Model umsg )
sequenceUpdate userUpdate userModel msgs ui =
    List.foldr
        (\msg ( ( userModel, prevCommand ), ui ) ->
            let
                ( ( newUserModel, newUserCommand ), newUi ) =
                    update userUpdate userModel msg ui
            in
                (
                    ( newUserModel
                    , Cmd.batch [ prevCommand, newUserCommand ]
                    )
                , newUi
                )
        )
        ( ( userModel, Cmd.none ), ui )
        msgs
