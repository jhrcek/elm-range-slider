module RangeSlider exposing (Model, Settings, StepSize, Msg, activate, view, update, subscriptions)

{-| A slider built natively in Elm

#The base model for the range slider
@docs Model

@docs Settings the settings for the slider

@docs StepSize How big each step for the slider will be

@docs Msg is the type expected by update

@docs update takes a model and a message and applies it to create an updated model

@docs activate returns everything that is needed to create a range slider

@docs subscriptions the necessary subscriptions to make everything work

@docs view creates a basic html structure for the range slider
-}

import Html exposing (Html, span, div, Attribute)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Mouse exposing (Position)
import Json.Decode as Json exposing ((:=))
import Css exposing (..)
import CssHooks exposing (..)
import Html.CssHelpers


{ id, class, classList } =
    Html.CssHelpers.withNamespace "rangeSlider"
{-| The base model for the slider
-}
type alias Model =
    { from : Float
    , to : Float
    , min : Float
    , max : Float
    , dragPosition : RangeDrag
    , stepSize : Maybe StepSize
    , formatter : Float -> String
    }


{-| The settings for the range slider
-}
type alias Settings =
    { stepSize : Maybe StepSize
    , formatter : Maybe (Float -> String)
    , from : Maybe Float
    , to : Maybe Float
    }


{-| How big each step for the slider will be
-}
type alias StepSize =
    Float


type RangeDrag
    = BeginDrag Drag
    | EndDrag Drag
    | None


type alias Drag =
    { start : Position
    , current : Position
    }


{-| The basic type accepted by the update
-}
type Msg
    = DragStart (Drag -> RangeDrag) Position
    | DragAt Position
    | DragEnd Position


{-| Creates an initial model
-}
initialModel : Settings -> Model
initialModel settings =
    { from = Maybe.withDefault 40.0 settings.from
    , to = Maybe.withDefault 60.0 settings.to
    , min = 0.0
    , max = 100.0
    , dragPosition = None
    , stepSize = settings.stepSize
    , formatter = Maybe.withDefault (toString) settings.formatter
    }


{-| Returns the necessities for initializing a range slider
-}
activate : Settings -> ( Model, Cmd Msg )
activate settings =
    ( initialModel settings, Cmd.none )


{-| Returns the subscriptions necessary to run
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    case model.dragPosition of
        None ->
            Sub.none

        _ ->
            Sub.batch [ Mouse.moves DragAt, Mouse.ups DragEnd ]


{-| takes a model and a message and applies it to create an updated model
-}
update : Model -> Msg -> ( Model, Cmd Msg )
update model msg =
    case msg of
        DragStart createRangeDrag xy ->
            ( { model | dragPosition = createRangeDrag <| Drag xy xy }, Cmd.none )

        DragAt xy ->
            ( { model | dragPosition = updateDrag model.dragPosition xy }, Cmd.none )

        DragEnd _ ->
            ( { model | to = getEndValue model, from = getBeginValue model, dragPosition = None }, Cmd.none )


{-| Displays the range slider
-}
view : Model -> Html Msg
view model =
    let
        barHeight =
            4

        containerWidth =
            200

        containerHeight =
            75

        toValue =
            getEndValue model

        toPosition =
            left <| pct <| toValue / model.max * 100

        fromValue =
            getBeginValue model

        fromPosition =
            left <| pct <| fromValue / model.max * 100

        styles =
            Css.asPairs >> Html.Attributes.style

        barHighlightWidth =
            Css.width <| pct <| (toValue - fromValue) / model.max * 100

        handleDiameter =
            20

        handleTop =
            top <| px <| toFloat (containerHeight - handleDiameter) / 2

        barTop =
            top <| px <| toFloat (containerHeight - barHeight) / 2

        fromHandle =
            span [ onMouseDown BeginDrag, styles [ position absolute, fromPosition, handleTop ], class [ Handle ] ] []

        toHandle =
            span [ onMouseDown EndDrag, styles [ position absolute, toPosition, handleTop ], class [ Handle ] ] []

        backgroundBar =
            span
                [ class [ BackgroundBar ]
                , styles
                    [ position absolute
                    , barTop
                    , left <| px 0
                    ]
                ]
                []

        highlightedBar =
            span [ styles [ position absolute, fromPosition, barTop, barHighlightWidth ], class [ BarHighlight ] ] []

        fromValueDisplay =
            span [ styles [ position absolute, fromPosition ], class [ Value ] ] [ Html.text <| model.formatter fromValue ]

        toValueDisplay =
            span [ styles [ position absolute, toPosition ], class [ Value ] ] [ Html.text <| model.formatter toValue ]

        toTick : Int -> Html a
        toTick percent =
            span
                [ styles [ position absolute, left <| pct <| (toFloat percent) * 10 ]
                , class
                    [ Tick
                    , (if Basics.rem percent 5 == 0 then
                        MajorTick
                       else
                        MinorTick
                      )
                    ]
                ]
                []

        axis =
            span [ class [ Axis ], styles [ position absolute ] ] <|
                List.map toTick [0..10]

        toLabel : Int -> Html a
        toLabel percent =
            span
                [ styles [ position absolute, left <| pct (toFloat percent) ], class [ AxisLabel ] ]
                [ Html.text <| toString percent ]

        axisLabels =
            span [ styles <| [ position absolute, left <| px 0, bottom <| px 0, Css.width <| px containerWidth, Css.height <| px 9 ] ] <|
                List.map toLabel [ 0, 50, 100 ]
    in
        div [ id Container ]
            [ span [ styles [ display inlineBlock, position relative, Css.width <| px containerWidth, Css.height <| px containerHeight ] ]
                [ backgroundBar
                , highlightedBar
                , fromHandle
                , toHandle
                , fromValueDisplay
                , toValueDisplay
                , axis
                , axisLabels
                ]
            ]


onMouseDown : (Drag -> RangeDrag) -> Attribute Msg
onMouseDown createRangeDrag =
    on "mousedown" <| Json.map (DragStart createRangeDrag) Mouse.position


updateDrag : RangeDrag -> Position -> RangeDrag
updateDrag rangeDrag position =
    case rangeDrag of
        BeginDrag { start } ->
            BeginDrag <| Drag start position

        EndDrag { start } ->
            EndDrag <| Drag start position

        None ->
            None


getEndValue : Model -> Float
getEndValue model =
    case model.dragPosition of
        None ->
            model.to

        BeginDrag _ ->
            model.to

        EndDrag { start, current } ->
            let
                difference =
                    (toFloat current.x) - (toFloat start.x)

                normalizedDifference =
                    difference * 100.0 / 200.0

                value =
                    valueBySteps model model.to normalizedDifference
            in
                clamp model.from model.max value


valueBySteps : Model -> Float -> Float -> Float
valueBySteps model baseValue normalizedDifference =
    case model.stepSize of
        Just stepSize ->
            stepSize * (toFloat <| round <| (baseValue + normalizedDifference) / stepSize)

        Nothing ->
            baseValue + normalizedDifference


getBeginValue : Model -> Float
getBeginValue model =
    case model.dragPosition of
        None ->
            model.from

        BeginDrag { start, current } ->
            let
                difference =
                    (toFloat current.x) - (toFloat start.x)

                normalizedDifference =
                    difference * 100.0 / 200.0

                value =
                    valueBySteps model model.from normalizedDifference
            in
                clamp model.min model.to value

        EndDrag _ ->
            model.from