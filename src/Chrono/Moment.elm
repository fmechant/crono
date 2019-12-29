module Chrono.Moment exposing
    ( Direction(..)
    , Duration
    , Era
    , Moment
    , TimeZone
    , and
    , chronologicalComparison
    , customZone
    , durationView
    , elapsed
    , fromMsSinceEpoch
    , here
    , hours
    , intoFuture
    , intoFutureForZone
    , intoPast
    , intoPastForZone
    , milliseconds
    , minutes
    , now
    , relevantTimeZonePeriod
    , seconds
    , toMsAfterEpoch
    , utc
    , zoneWithSameOffset
    )

{-| The moment model represents specific moments in time. For example the moment you
first started reading this sentence.
-}

import Task exposing (Task)
import Time as CoreTime


{-| A specific moment in time.
-}
type Moment
    = Moment Int


{-| Get the current moment when this task is run.
-}
now : Task x Moment
now =
    Task.map (fromMsSinceEpoch << CoreTime.posixToMillis) CoreTime.now


{-| Get the moment that occured the number of milliseconds after the epoch.

Typically only used when receiving a moment that was previously exported.

-}
fromMsSinceEpoch : Int -> Moment
fromMsSinceEpoch ms =
    Moment ms


{-| Get the number of milliseconds after the epoch that this moment occured.

Do not use this for calculations, only for exporting the moment.

-}
toMsAfterEpoch : Moment -> Int
toMsAfterEpoch (Moment ms) =
    ms


{-| Move the moment into the future for a duration.

Do not use this to move days, weeks, or months. Use Date and GregorianCalendar for that.

-}
intoFuture : Duration -> Moment -> Moment
intoFuture (Duration durationInMs) (Moment momentInMs) =
    Moment <| momentInMs + durationInMs


{-| Move the moment into the past for a duration.

Do not use this to move days, weeks, or months. Use Date and GregorianCalendar for that.

-}
intoPast : Duration -> Moment -> Moment
intoPast (Duration durationInMs) (Moment momentInMs) =
    Moment <| momentInMs - durationInMs


{-| Compare two moments chronologically. Typically used with `List.sortWith`.

    import List

    let
        base = fromMsSinceEpoch 0
        later = intoFuture (minutes 5) base
        earlier = intoPast (hours 20) base
    in
    [earlier, base, later] == List.sortWith chronologicalComparison [later, earlier, base]
    --> True

-}
chronologicalComparison : Moment -> Moment -> Order
chronologicalComparison (Moment m) (Moment n) =
    Basics.compare m n



---- DURATION ----


{-| Duration represents a laps of time. It is represented in the moment model,
because we are thinking about actual elaps of specific milliseconds, seconds, minutes and hours.

It has no way of describing days, because one day is not always 24 hours.
For example, moving 24 hours is not the same as moving a day. In Europe it is only
the same in about 363 days a year, because of daylight time savings.

-}
type Duration
    = Duration Int


{-| Direction represents the relative position of one moment regarding another moment,
whether it is into the future, or into the past.
-}
type Direction
    = IntoTheFuture
    | IntoThePast


{-| A duration of some milliseconds.
Only use positive values, if you want your code to be predictable.
-}
milliseconds : Int -> Duration
milliseconds value =
    Duration value


{-| A duration of some seconds.
Only use positive values, if you want your code to be predictable.
-}
seconds : Int -> Duration
seconds value =
    milliseconds <| value * 1000


{-| A duration of some minutes.
Only use positive values, if you want your code to be predictable.
-}
minutes : Int -> Duration
minutes value =
    seconds <| value * 60


{-| A duration of some hours.
Only use positive values, if you want your code to be predictable.
-}
hours : Int -> Duration
hours value =
    minutes <| value * 60


{-| Combine two durations.

It has an odd signiture to be able to efficiently use it using the pipe (|>) operator.
Example:

    hours 2
        |> and minutes 45
        |> durationView
    --> { hours = 2, minutes = 45, seconds = 0, milliseconds = 0}

-}
and : (Int -> Duration) -> Int -> Duration -> Duration
and fct value (Duration duration) =
    let
        (Duration toAdd) =
            fct value
    in
    Duration (duration + toAdd)


{-| Show the duration split up in milliseconds, seconds, minutes and hours.
-}
durationView : Duration -> { milliseconds : Int, seconds : Int, minutes : Int, hours : Int }
durationView (Duration duration) =
    let
        ( wholeHours, withoutHours ) =
            substractWhole duration 3600000

        ( wholeMinutes, withoutMinutes ) =
            substractWhole withoutHours 60000

        ( wholeSeconds, withoutSeconds ) =
            substractWhole withoutMinutes 1000
    in
    { milliseconds = withoutSeconds, seconds = wholeSeconds, minutes = wholeMinutes, hours = wholeHours }


{-| How much time has elapsed between the moments.

The result is a duration, without the indication whether one moment is in the future
or in the past regarding to the other moment.

-}
elapsed : Moment -> Moment -> ( Duration, Direction )
elapsed (Moment from) (Moment to) =
    let
        diff =
            to - from

        dir =
            if diff < 0 then
                IntoThePast

            else
                IntoTheFuture
    in
    ( Duration <| abs diff, dir )


{-| Get the current moment, every duration.

If it is unclear to you why it returns a Sub, please review the Elm architecture.

-}
every : Duration -> (Moment -> msg) -> Sub msg
every (Duration duration) function =
    CoreTime.every (toFloat duration) (CoreTime.posixToMillis >> fromMsSinceEpoch >> function)



---- TIMEZONE ----


{-| We define a different time zone type than that defined in elm/time,
because we need access to the offset.
-}
type TimeZone
    = TimeZone Int (List Era)


type alias Era =
    { start : Int
    , offset : Int
    }


utc : TimeZone
utc =
    TimeZone 0 []


customZone : Int -> List Era -> TimeZone
customZone defaultOffset eras =
    let
        sortedEras =
            List.sortBy .start eras
    in
    TimeZone defaultOffset sortedEras


{-| A naïve implementation of transforming the elm/time Zone to this TimeZone.
It only works on zones without an era. We need to find a way to deal with
time zones that have eras.
-}
zoneWithSameOffset : CoreTime.Zone -> TimeZone
zoneWithSameOffset zone =
    let
        day =
            CoreTime.toDay zone (CoreTime.millisToPosix 0)

        hour =
            CoreTime.toHour zone (CoreTime.millisToPosix 0)

        minute =
            CoreTime.toMinute zone (CoreTime.millisToPosix 0)

        offset =
            if day == 1 then
                hour * 60 + minute

            else
                (hour - 24) * 60 + minute
    in
    TimeZone offset []


{-| The relevant time zone period in the time zone for the moment.
-}
relevantTimeZonePeriod : TimeZone -> Moment -> { start : Maybe Moment, end : Maybe Moment, offset : Int }
relevantTimeZonePeriod (TimeZone defaultOffset eras) (Moment ms) =
    List.foldl
        (\era { start, end, offset } ->
            let
                startInMs =
                    minutesInMs era.start
            in
            if startInMs <= ms then
                { start = Just <| Moment startInMs, end = Nothing, offset = era.offset }

            else if end == Nothing then
                { start = start, end = Just <| Moment startInMs, offset = offset }

            else
                { start = start, end = end, offset = offset }
        )
        { start = Nothing, end = Nothing, offset = defaultOffset }
        eras


here : Task x TimeZone
here =
    Task.map zoneWithSameOffset CoreTime.here



---- HELPER FUNCTIONS ----


minutesInMs : Int -> Int
minutesInMs value =
    value * 60000


{-| Subtract the whole part, when dividing by the factor, and return the whole part, and the remaining value.
-}
substractWhole : Int -> Int -> ( Int, Int )
substractWhole value factor =
    let
        whole =
            value // factor
    in
    ( whole, value - whole * factor )


{-| Don't use this. Only useful for internal calculations in Date and Time.
-}
intoFutureForZone : TimeZone -> Moment -> Moment
intoFutureForZone zone moment =
    let
        ms =
            toMsAfterEpoch moment

        relevantPeriod =
            relevantTimeZonePeriod zone moment
    in
    fromMsSinceEpoch (ms + minutesInMs relevantPeriod.offset)


{-| Don't use this. Only useful for internal calculations in Date and Time.
-}
intoPastForZone : TimeZone -> Moment -> Moment
intoPastForZone zone moment =
    let
        ms =
            toMsAfterEpoch moment

        relevantPeriod =
            relevantTimeZonePeriod zone moment
    in
    fromMsSinceEpoch (ms - minutesInMs relevantPeriod.offset)
