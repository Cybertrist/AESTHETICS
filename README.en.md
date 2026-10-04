<div align="center">

<p>
  <a href="README.md"><img src="docs/langues/fr-off.png" alt="Français" width="150" /></a>
  <img src="docs/langues/en-on.png" alt="English" width="150" />
</p>

<img src="docs/en/banniere.png" alt="AESTHETICS: every set, every record, every gain. To become the best version of myself. Android, strength training, offline. Flutter, 608 exercises, 116 programmes, no account, Fold." width="100%">

<br><br>

**My strength training app, on Android: the workout, the rest timer, the records, and everything they tell over the months.**

</div>

I train seven times a week, as much strength as cardio, and have more than 460 workouts behind me. The name comes from a movement I love, aesthetics: the one of Zyzz and David Laid, where a physique is built the way a piece of work is crafted. I wanted an app in that image: beautiful, clean, practical, with the body in 3D rather than grey tables.

AESTHETICS does what I need at the gym: log a set in one tap, know what to load, watch a record fall, and understand afterwards what the month added up to.

Everything stays on the phone, in files I can read: no account to create, no server, no locked feature. Black background, grey cards, white buttons; colour is only there to say something.

<p align="center">
<img src="docs/exercices/bench-press.webp" alt="Bench press" width="24%">
<img src="docs/exercices/barbell-row.webp" alt="Barbell row" width="24%">
<img src="docs/exercices/arnold-press.webp" alt="Arnold press" width="24%">
<img src="docs/exercices/bulgarian-split-squat.webp" alt="Bulgarian split squat" width="24%">
<br>
<img src="docs/exercices/barbell-curl.webp" alt="Barbell curl" width="24%">
<img src="docs/exercices/cable-fly.webp" alt="Cable fly" width="24%">
<img src="docs/exercices/cable-lateral-raise.webp" alt="Cable lateral raise" width="24%">
<img src="docs/exercices/back-extension.webp" alt="Back extension" width="24%">
</p>

<img src="docs/en/sections/s00.png" alt="00 Contents" width="100%">

<p align="center">
<a href="#fonctionnalites"><img src="docs/en/sommaire/01.png" alt="01 Features" width="31%"></a>
<a href="#ecrans"><img src="docs/en/sommaire/02.png" alt="02 The screens" width="31%"></a>
<a href="#seance"><img src="docs/en/sommaire/03.png" alt="03 The workout" width="31%"></a>
<br>
<a href="#records"><img src="docs/en/sommaire/04.png" alt="04 1RM and records" width="31%"></a>
<a href="#programmes"><img src="docs/en/sommaire/05.png" alt="05 Programmes and progression" width="31%"></a>
<a href="#exercices"><img src="docs/en/sommaire/06.png" alt="06 The exercises" width="31%"></a>
<br>
<a href="#recuperation"><img src="docs/en/sommaire/07.png" alt="07 Recovery" width="31%"></a>
<a href="#serie"><img src="docs/en/sommaire/08.png" alt="08 The streak" width="31%"></a>
<a href="#resume"><img src="docs/en/sommaire/09.png" alt="09 The monthly recap" width="31%"></a>
<br>
<a href="#badges"><img src="docs/en/sommaire/10.png" alt="10 The badges" width="31%"></a>
<a href="#import"><img src="docs/en/sommaire/11.png" alt="11 Bringing your history along" width="31%"></a>
<a href="#donnees"><img src="docs/en/sommaire/12.png" alt="12 My data" width="31%"></a>
<br>
<a href="#architecture"><img src="docs/en/sommaire/13.png" alt="13 Architecture" width="31%"></a>
<a href="#tests"><img src="docs/en/sommaire/14.png" alt="14 The tests" width="31%"></a>
<a href="#construire"><img src="docs/en/sommaire/15.png" alt="15 Building and licences" width="31%"></a>
</p>

<a id="fonctionnalites"></a>
<img src="docs/en/sections/s01.png" alt="01 Features" width="100%">

<img src="docs/en/schemas/fonctionnalites.png" alt="Fifteen features. The workout: one table per exercise, last time’s load next to each set, twelve set types; tick it, and the row turns green. The rest timer, which starts by itself after every completed set: 90 seconds by default, set per exercise, ten seconds more or less in one tap. The records: weight, estimated 1RM, best set, reps, volume, announced during the workout with a golden PR badge. Programmes and progression: 116 programme ideas, four ways to make the loads climb, and a suggested routine once the habit is clear. 608 exercises, 496 of them animated: twenty muscles, search in French or English, an equipment filter, and your own exercises. Plates and warm-up: what to load on each side of the bar, and the warm-up steps. Recovery: eighteen muscles tracked, from orange to green, and the group to train today. The streak, counted in weeks. The monthly recap: ten pages to swipe through, the month’s volume turned into objects, and a yearly recap. The badges: nine with tiers, six secret ones, eighteen milestones, no experience points and no ranks. The body: weight, body fat, eight measurements, photos from three angles. Sharing: five cards at the end of a workout, one more if there is a record. Bringing your history along from a CSV export. Yours: files on the phone, no account, no server. The unfolded screen: a rail and two columns from 840 points wide." width="100%">

Four tabs are enough: **Home**, **Train**, **Progress**, **Profile**. Nutrition, sleep and a coach exist in the code, shelved behind a build flag: I want a solid strength training app first. The app itself is in French.

<a id="ecrans"></a>
<img src="docs/en/sections/s02.png" alt="02 The screens" width="100%">

A bar of four tabs at the bottom, and the workout in progress always within reach, shrunk into a thin bar, until it is finished. Every screenshot comes from the app's demo, filled with sample data.

<img src="docs/en/schemas/captures-telephone.png" alt="Sixteen phone screens. Home: the streak in weeks, the current week, the latest workouts. Routines: today’s suggested routine, then your own, as day cards. A routine: the muscles targeted, the exercises, the planned sets. The workout: tick it and the row turns green, a record turns gold. Rest: the blue ring, ten seconds more or less. End of workout: the volume, the gap with last time, the records beaten. Sharing: cards to swipe through. The exercises: muscles as tiles, 608 exercises, search. An exercise: the animation, the muscles targeted, how to do it. Its records, with the PR badge. Progress: the month’s volume, week by week. Recovery, muscle by muscle, and the group to train. Measurements, each area tied to the body. The monthly recap: the month’s volume turned into nine fire engines. Profile: the goal, the month’s calendar, the badges. The badges: nine with tiers, and secret ones. All of them come from the demo. The app itself is in French." width="100%">

<img src="docs/en/schemas/palette.png" alt="Palette: background #000000, cards #131315, button #FFFFFF, muscles #E0393E, completed set #228B22, timer #1E9BF0, record #FFBE0B, streak #FF9A00." width="100%">

Each colour has one job. Forest green validates a set, blue is reserved for the rest timer, gold for records, orange for the streak, and red for the muscles worked on the character. Main buttons are white with black text. The typeface is Figtree; Montserrat is only used for the big titles of the recap.

<a id="seance"></a>
<img src="docs/en/sections/s03.png" alt="03 The workout" width="100%">

<img src="docs/en/schemas/seance.svg" alt="The workout, on an animated phone, in six steps. The workout screen shows the top bar (minimise, timer pill, Finish), the Duration, Volume, Sets box, and the Bench press exercise with its table: Set, Previous, Kg, Reps, three sets whose previous values are 80 kg × 8, 80 kg × 8 and 80 kg × 7. Step 1: one tap on the tick validates the first set, 80 kg × 8; the row turns green, the volume rises to 640 kg and the counter to 1 set. Step 2: the rest timer starts on its own, 90 seconds by default, 60 at most after a warm-up set, never in the middle of a superset nor after the last set; the blue pill shows the time left. Step 3: one tap on the pill opens the timer full screen, a blue ring that empties, with the −10, +10 and Stop buttons; +10 adds ten seconds. Step 4: when the rest ends, the phone buzzes briefly at 3, 2 and 1 second, then longer with the end sound; in the background, a Rest over notification takes over. Step 5: the second set goes to 82.5 kg × 8 and beats two records, the heaviest weight (80 kg before) and the estimated 1RM (100.3 kg before, 103.5 kg now); the row turns gold, the PR badge opens at the top of the screen and announces each record, and the box gains a Records column. Step 6: the chevron minimises the workout into a Workout in progress bar sitting above the tabs, with the clock and the Resume and Discard buttons. Every action is written to the phone." width="100%">

During a workout, everything fits on one screen: tick a set, the rest starts by itself and tells you when it is over. A set that beats what you have already done on the exercise turns gold, and the app says so right away. The workout can shrink into a bar above the tabs without stopping, and every action is written to the phone as it happens: closing the app loses nothing.

Each set has a type, twelve in all: normal, warm-up, drop set, failure, left, right, negative, partials, myo-reps, feeder, top set, back-off. Only the warm-up counts neither in the volume nor in the records. An exercise can be logged in seven ways, from weight and reps to distance and time, and the table changes its columns to match. RPE or RIR can be added as a column.

<details>
<summary><b>Plates and warm-up</b></summary>

The **Plates and warm-up** page opens from an exercise's menu. It says what to load on each side of the bar: the target load minus the bar, divided by two, then plates taken from heaviest to lightest among those you own, never going over the target. If it cannot be reached, the page gives the closest load with that equipment. Bars and plates are set once, in the settings.

It also suggests the warm-up: the empty bar for ten reps, then 40% for eight, 60% for five and 80% for three, rounded to the equipment's step. **Add to the exercise** puts these steps at the top, as warm-up sets.

</details>

<a id="records"></a>
<img src="docs/en/sections/s04.png" alt="04 1RM and records" width="100%">

<img src="docs/en/schemas/records.svg" alt="Estimated 1RM and records. The estimated 1RM of a ticked set, warm-up excluded, comes from two formulas: Epley, weight × (1 + reps / 30), and Brzycki, weight × 36 / (37 − reps). For 80 kg × 8, Epley gives 101.33 kg and Brzycki 99.31 kg; up to 10 reps their average is kept, 100.32 kg. For 60 kg × 12, beyond 10 reps, Brzycki (86.40 kg) is dropped and Epley alone gives 84.00 kg. At 1 rep, the 1RM is the weight itself. At the end of the workout, five record types are compared with the best values of earlier workouts. On the bench press, today’s workout has a warm-up of 40 kg × 10, then 82.5 kg × 8, 82.5 kg × 6 and 80 kg × 8, that is 1,795 kg. Heaviest weight: 80 kg before, 82.5 kg today, a record by 2.5 kg. Estimated 1RM: 100.3 kg before, 103.5 kg today, a record by 3.1 kg. Best set by volume: 640 kg before, 660 kg today, a record by 20 kg. Most reps: 8 against 8, equal, no record. Volume in one workout: 1,840 kg before, 1,795 kg today, no record. Four rules: the old value must be strictly exceeded; the warm-up counts neither in the volume, nor in the 1RM, nor in the records; the reps record only applies to an exercise that has never had a weight; an exercise done for the first time beats no record. During the workout, the record alert follows the heaviest weight, the estimated 1RM and the reps at a given weight." width="100%">

The estimated 1RM comes from two classic formulas, Epley and Brzycki: the app keeps their average up to ten reps, then Epley alone beyond. At the end of each workout, five values per exercise are compared with the best of earlier workouts, and the old one must be beaten, not matched. Warm-up sets count nowhere, and an exercise done for the first time beats no record.

<a id="programmes"></a>
<img src="docs/en/sections/s05.png" alt="05 Programmes and progression" width="100%">

A **routine** is a template workout: its exercises, its sets, its rep ranges. A **programme** arranges routines in a cycle, knows where you are in it, and makes the loads climb. The library offers 116 programme ideas, sorted by shelf: getting started, building muscle, gaining strength, at home with no equipment, with dumbbells, when time is short. Adding one creates its routines, ready to start.

<img src="docs/en/schemas/progression.svg" alt="How a programme’s loads progress, in four worked examples. The setting is per programme: four modes, None, Progressive load, Double progression and Weekly undulating, a load increment, here 2.5 kg, and a deload week, here every 4 weeks. Progressive load, bench press, 3 sets of 8: at 60 kg every rep is done, so the next workout moves to 62.5 kg; there the third set stops at 6 reps, so the same load comes back; completed this time, it goes up to 65 kg. Double progression, barbell row, 3 sets of 8 to 10 reps at 50 kg: the target goes from 8 to 9 then 10 reps, one more per workout; once the top of the range is reached on every set, the load goes up to 52.5 kg and the target returns to 8. Weekly undulating, squat: the last workout, 80 kg for 8 reps, gives an estimated 1RM of 100.3 kg, and the load is the 1RM divided by 1 plus reps over 30, times 0.92, rounded to the step; heavy week, 5 reps at RPE 8.5, 80 kg; medium week, 8 reps at RPE 8, 72.5 kg; light week, 12 reps at RPE 7, 65 kg; the fourth week starts again with a heavy one. Deload week, the fourth and the eighth: out of 4 sets of 8 at 80 kg and RPE 8, 2 remain, at 72.5 kg, that is 90% rounded to the step, and RPE 6; warm-ups stay. With the None mode, the sets stay those of the routine. The programme week moves forward with finished workouts, not with the calendar." width="100%">

Each programme chooses how its loads evolve: “None”, “Progressive load”, “Double progression” or “Weekly undulating”, with a load increment and, if you want, a deload week every N weeks. When a workout of the programme starts, the app looks at the last time each exercise was done and sets the sets accordingly. The programme week moves forward with finished workouts, not with the calendar. Without a programme, the routine starts as it is.

<img src="docs/en/schemas/suggestion.svg" alt="The suggested routine of the day, over eight weeks of workouts and an animated phone. Today is Friday 2 October. The reading goes down the column of the last eight Fridays, from 7 August to 25 September, and counts how often the same routine was done there: Lower volume six times, Upper strength once, and one Friday with no workout. The threshold is 6 times out of 8: Lower volume is suggested. On the phone, the Routines pane of the Train tab shows, under “Suggested for this Friday”, the Lower volume card from the Upper/Lower 4 days programme, 7 exercises, 50 minutes, with its reason: “You did this workout on 6 of the last 8 Fridays. Last time: 25 September.”, and two buttons, Start and Another one. The finger taps Another one, and the queue moves on in three ranks. 1, that weekday’s habits, even just once in 8, the most regular first: Upper strength. 2, next in the active programme, the routine that follows the last one done in the cycle: Upper volume, “Next in your programme. Last time: 24 September.”. 3, the others, the longest-waiting first and never-done ones last: Abs, “Not done since 18 July.”. Nothing is suggested up front if no routine reaches 6 out of 8, if it was already done today, or if it no longer exists. Once the queue is empty, the app writes: “No other suggestion for today: pick a routine below.”. Another one sets the routine aside until tomorrow; neither muscle recovery nor the programme’s planned days play any part in this choice." width="100%">

At the top of the Routines pane, the app only suggests a routine when it is sure: the same routine must have been done on that weekday at least 6 times in the last 8 weeks. “Another one” sets it aside until tomorrow and moves a queue forward: that weekday’s habits, then what comes next in the active programme, then the routine that has waited the longest. Each suggestion shows its reason, and “Start” launches the workout.

<a id="exercices"></a>
<img src="docs/en/sections/s06.png" alt="06 The exercises" width="100%">

The catalogue holds **608 exercises**, **496 of them animated**; the other 112 are holds and stretches, shown by their pose. Each has its name in French and English, its primary and secondary muscles among twenty, its equipment, its steps and its tips.

- **Search.** The search ignores accents and case, and understands French as well as English, nicknames (“pecs”, “quads”) and equipment. On a tie, the exercise done most often comes first.
- **Filter.** A row of tiles per muscle group, plus Favourites, Cardio and Stretching; a **Filter** panel by equipment, in pictures, with several choices; and the Recent and My exercises chips.
- **Read an exercise.** Four tabs: **About** (the animation, the muscles targeted on the body, how to do it, alternative exercises), **History**, **Progress** (the curve of estimated 1RM, load and volume, from one month to the whole history) and **Records**.
- **Create your own.** A name, a way of logging, the muscles involved on the character, the equipment, a photo or a video. A personal variant is copied from a catalogue exercise in one tap.

<a id="recuperation"></a>
<img src="docs/en/sections/s07.png" alt="07 Recovery" width="100%">

<img src="docs/en/schemas/recuperation.svg" alt="Recovery, muscle by muscle. A workout of 4 sets of bench press (chest as the primary muscle, front delts and triceps as secondary ones) and 3 sets of leg extension (quads) loads each muscle with fatigue: sets × weight × remainder ÷ 6, with a weight of 1 for a primary muscle and 0.5 for a secondary one, six sets saturating the muscle. Right afterwards the chest stands at 0.67 fatigue, that is 33 % recovered, the quads at 0.50, that is 50 %, the front delts and triceps at 0.33, that is 67 %. Fatigue then fades in a straight line, each muscle over its own duration: 60 hours for the chest, 72 for the quads, 48 for the delts and triceps. Every twelve hours the timeline reads the percentages: at 12 hours, 47, 58 and 75 %; at 24 hours, 60, 67 and 83 %; at 36 hours, 73, 75 and 92 %; at 48 hours, 87, 83 and 100 %; at 60 hours, 100, 92 and 100 %; at 72 hours, 100, 100 and 100 %. A muscle turns from orange to green at the screen’s “ready” threshold, 90 %: around 33 hours for the triceps and delts, 51 hours for the chest, 57 hours for the quads. On the phone, the Recovery page shows the overall ring, the average of the 18 tracked muscles, which drops to 90 % after the workout, six muscle tiles and the “Recommended today” card: before the workout, legs; afterwards, back, whose lats are 100 % recovered. The recommended group is the one whose least recovered muscle is the most recovered; on a tie, the one that has gone longest without work." width="100%">

Every completed set tires the muscles of the exercise, fully for a primary muscle, by half for a secondary one; six sets are enough to saturate a muscle. Fatigue then fades in a straight line, over 48, 60 or 72 hours depending on the muscle, and only the workouts of the last 96 hours count. The Recovery page of the Progress tab turns this into a percentage per muscle, green from 90%, orange below, and recommends the group whose least recovered muscle is the most recovered.

<a id="serie"></a>
<img src="docs/en/sections/s08.png" alt="08 The streak" width="100%">

<img src="docs/en/schemas/serie.svg" alt="The streak, a flame counted in weeks, over a six-week calendar and an animated phone. Today moves from 31 August to 6 October 2026. Wednesday 2 September, a first workout: the streak is 1, and the Streak page says “First week of your streak. Come back next week to make it grow.”. Friday 11 September, three workouts in the week: 2, because three workouts still make one week. Sunday 20 September, a single workout, on the Sunday: 3. Monday 21 September, the current week is still empty: it breaks nothing, the streak stays at 3. Thursday 24 September, a workout: 4, “You kept it up 4 weeks in a row. Nicely done!”. Wednesday 30 September, still nothing this week: still 4. Monday 5 October, the empty week is now behind: the count stops, the streak drops to 0, the flame fades and the page says “One workout this week and your streak begins.”. Tuesday 6 October, a workout: the streak restarts at 1. On the Streak page, the big number and the flame follow, and the streak calendar underlines each week that counts with a band, with an orange disc on each workout day. Three rules: one workout is enough for a week to count; the current week, still empty, breaks nothing; the first empty week left behind resets to zero. The weekly workout goal plays no part in the streak, and a workout is dated by when it started. The same flame shows at the top of the home screen, on the profile and on a workout’s share card." width="100%">

The streak is counted in weeks, not days: a single workout is enough for a week to count, and the weekly workout goal plays no part. The count goes back from the current week, which breaks nothing while it is still empty, and stops at the first week with no workout. The “Streak” page shows the number, the flame and a calendar where each week kept is underlined with a band.

<a id="resume"></a>
<img src="docs/en/sections/s09.png" alt="09 The monthly recap" width="100%">

<img src="docs/en/schemas/resume.svg" alt="The monthly recap, story-style, on an animated phone. Ten pages follow one another, one tap on the screen to move on, its left third to go back, with no timer: the opening; the workouts of September 2026, one line each with its duration and volume, then the total, 12 h 53 and 70 910 kg; consistency, 12 workouts, 20 % more than in August, and nine months of squares; the volume, 70 910 kg, 12 % more than in August, and twelve months as bars; the volume in objects; the streak, 11 weeks in a row; the muscles, a nine-axis radar in front of the previous month’s; the records, 3 new ones; the five favourite exercises; the summary to share. The fifth page turns the volume into one object out of 25, from the 250 g burger to the 225-tonne Statue of Liberty. An object is kept if the volume divided by its mass runs from 0.93 to 99.5: here 14 objects, from 713 kg to 76 t. The multiple is rounded to a whole number if it is off by 8 % at most or from 10 upwards, otherwise to one decimal; whole numbers come first, from most to least accurate, then the smallest multiple; the Statue of Liberty, as a percentage, closes the list. The month’s seed, 2026 × 12 + 9 = 24 321, picks choice no. 4 out of 15: × 12 elephants, “That’s like lifting 12 elephants!”. One seed in six picks a burger or a baguette. The yearly recap follows the same mechanics, with the year as its seed: for 2026 so far, 545 610 kg, that is × 68 T. rexes." width="100%">

Every finished month has its recap in ten full-screen pages, flipped through by touch, each of which can be shared as an image. The fifth weighs the month’s volume in an object picked from a scale of twenty-five, from the burger to the Statue of Liberty: the object is chosen by a seed derived from the month, so the same recap always reopens on the same object. The yearly recap uses the same ten pages for the whole year.

<a id="badges"></a>
<img src="docs/en/sections/s10.png" alt="10 The badges" width="100%">

<img src="docs/en/schemas/badges.svg" alt="The badges of AESTHETICS. Nine tiered badges, as hexagonal crests in their own colour, grey with a padlock until something is earned: Perfect week (weeks where your session goal is met; tiers 1, 3, 5, 10, 15, 20, 30, 40, 50, 75), Early bird (sessions started between 4 and 7 a.m.; 1, 5, 10, 25, 50, 75, 100, 150, 200, 300), Streak (your longest run of weeks with a session; 2, 4, 8, 12, 15, 20, 26, 39, 52, 104), Weekend warrior (sessions started on a Saturday or a Sunday; same tiers as Early bird), Routine collector (routines in your library; 1, 3, 5, 10, 25), Exercise explorer (different exercises with at least one set done; 5, 10, 25, 50, 75, 100, 150, 200, 300, 400), Marathon (sessions of two hours or more, and under twelve; 1, 5, 10, 25, 50), Night owl (sessions ended after 11 p.m. or before 4 a.m.; same tiers as Early bird) and Record hunter (exercises where you hold a load record; same tiers). After 42 sessions, eight of nine are earned and each crest shows its last reached tier in large digits; Marathon stays grey. The detail of Early bird, as in the app: “Level 1 · 4 sessions”, a gauge, “1 more session for level 2”. On a Tuesday at 6:42 a.m., a fifth session starts before 7 a.m.: the threshold is met, the crest goes from 1 to 5, “Level 2 · 5 sessions”, “5 more sessions for level 3”. Six secret badges show “???” while their counter is at zero and only give a hint; a second session on the same Tuesday reveals “Double”, two sessions on the same day. The milestones, as shields, count finished sessions: 1, 10 and 25 are reached, 6 remain before the 50 one. No experience points, no rank." width="100%">

Badges are not claimed: they are recounted from finished workouts, and a badge goes up a level when its counter reaches the next threshold. Nine badges have tiers, six stay secret until their first time, and the milestones only count workouts, from 1 to 2,000. There are no points and no ranks: a crest only says what you have done.

<a id="import"></a>
<img src="docs/en/sections/s11.png" alt="11 Bringing your history along" width="100%">

<img src="docs/en/schemas/import.svg" alt="Bringing your history into AESTHETICS from the CSV file exported by another app. The file export.csv has five columns, separated by semicolons: Date, Séance, Exercice, Charge (kg) and Répétitions. Each one is recognised: the date, the session name, the exercise, the load in kilos, the repetitions. Its six rows are read one after the other and become two sessions: “Haut du corps”, on 2 March 2026 at 6:30 p.m., with two sets of Développé couché barre at 80 kg and one of Tirage horizontal poulie at 55 kg, then “Jambes”, on 4 March at 6:45 p.m., with one set of Squats at 100 kg and two of Squat avant barre, at 60 and 62.5 kg. Same date and same title make one session; consecutive rows for the same exercise make its sets. Every name is then matched to the catalogue, in order: your past choices, the synonym table, the identical name, then the likeness. “Développé couché barre”, normalised to “bench press barbell”, is in the 85-entry table: Développé couché, recognised automatically. “Squats” becomes “squat”, identical to the name Squat. “Tirage horizontal poulie” scores 0.97 for Tirage horizontal, the next one 0.85: above the 0.90 threshold with a gap of at least 0.05, it is recognised automatically. “Squat avant barre” scores 0.84 for Squat and 0.70 for Squat avant: neither reaches 0.90, the name is to be confirmed. On the phone, after “Browse” and the analysis, step 3 of 5, “Exercises”, shows that name with its suggestions “Squat · 84%”, “Squat avant · 70%” and “Custom exercise”, and the button “1 more to confirm” stays locked. One tap on “Squat avant · 70%”: everything is matched, four names recognised, “Continue”. The score is 0.8 times the weighted common words plus 0.2 times the letters; below 0.60, nothing is suggested. The choice is remembered for later imports." width="100%">

The history from another app comes in through its CSV export: columns are recognised from their headers, in French or English, and each row becomes a set in its workout. Exercise names are then matched to the catalogue, first through a synonym table, then by a likeness score. A name is only accepted on its own from 0.90, with a 0.05 lead over the next one; everything else is shown to you before importing, and your choices are remembered for next time. Any table works too, by saying which column holds what, and every import can be reviewed or undone.

<a id="donnees"></a>
<img src="docs/en/sections/s12.png" alt="12 My data" width="100%">

<img src="docs/en/schemas/donnees.svg" alt="My data, in AESTHETICS. Everything lives on the phone, in the app’s folder: one JSON file per collection (profile, settings, sessions, routines, programmes, measures…), photos kept apart, and every write goes through a temporary file, then a rename. The app says so itself: “No account, no server, no ads.” On the phone, the “My data” page of the settings shows what is on this phone (1.8 MB, 44 sessions, 6 routines, 12 measures) and four groups: keep my data safe, coming from another app, use my data elsewhere, danger zone. Three gestures start there. One: “Export as a table”, as CSV or JSON, for sessions, custom exercises and measures; the file aesthetic-seances-2026-10-04.csv has one row per set and can be imported again as is, with a comma or a semicolon, in UTF-8; several tables are gathered in a ZIP. Two: “Make a backup”, full (a ZIP archive with donnees.json, manifeste.json and the photos) or data only (one JSON file); the file aesthetic-sauvegarde-2026-10-04.zip is restored on another phone, where its content is shown before confirming; it replaces everything, nothing is merged, and it is refused if it comes from a newer version of the app. Three: “Phone copies”; “Back up now” stores aesthetic-20261004-1830.json in the copies folder, next to the data, without photos, and the last ten are kept. A copy is only made on request, or before “Erase everything” if the option stays ticked: there is no automatic backup. If a file can no longer be read at startup, it is set aside under the name seances.json.abime, never overwritten, and the app shows the alert “A data file is damaged”: nothing was erased, and it says where the rescue copy is." width="100%">

Your data are JSON files stored on the phone, one per collection: no account, no server. The “My data” page lets you export them as CSV or JSON, make a full backup to restore on another phone, and keep quick copies on the device. No backup is automatic: a copy is made when you ask for one, or just before “Erase everything”. If a file can no longer be read, it is set aside without being overwritten and the app tells you when it opens.

<a id="architecture"></a>
<img src="docs/en/sections/s13.png" alt="13 Architecture" width="100%">

<img src="docs/en/schemas/stack.svg" alt="The AESTHETICS stack. At the base, Flutter 3: the whole app, in Dart, one codebase for the phone and the unfolded screen, with no code generation. On top, five sockets, what strength training needs, and each package stacks on its own. The screen: provider for state, repositories provided to the whole tree and the screen listening to them; go_router for every route, each module bringing its own; fl_chart for the curves on the exercise page and the charts in Progress; path_drawing for the pictograms, drawn from paths; intl and flutter_localizations for dates, numbers and system texts in French. The data, JSON files on the phone: path_provider, the app folder where each collection has its file; uuid, a v4 identifier per workout, per exercise, per set; archive, the full backup and the export in a ZIP archive; collection, to search and group in the repositories’ lists; shared_preferences, a single key in the whole code. The workout: wakelock_plus, the screen stays on while the workout is open; flutter_local_notifications, the end of rest, the workout in progress and the reminders; audioplayers, the end-of-rest sound, the spoken countdown and the record sound; vibration, one tick per second for the last three seconds then a longer buzz; timezone and flutter_timezone, local time for scheduled notifications. Media: image_picker, workout, profile, progress and custom exercise photos; video_player, exercise and workout videos; cached_network_image, exercise images given by a URL; path, file names of the workout media. Sharing: share_plus, to share a workout card, an export or a backup; file_picker, to pick the file to import or restore; url_launcher, to open a link; permission_handler, the notification permission at sign-up; health, sending a finished workout to Health Connect, on request. Under the base, set apart: mobile_scanner, http and flutter_markdown_plus are shelved for later, imported only by nutrition and coach, two modules hidden by default; flutter_svg and csv are declared but never imported, the CSV import having its own reader. Two paths cross the stack. During a workout, the screen stays on, the ticked set is written, and the end of rest buzzes, rings, or notifies you if the app is in the background. For a full backup, the JSON files and the photos go into an archive, which you share; to restore, you pick the file." width="100%">

AESTHETICS is written in Flutter, with no code generation. Twenty-six packages are imported by the strength training part; the diagram groups them by what they serve, from screen state to the end-of-rest sound. Three more only serve the shelved modules, and two are declared without being imported.

<img src="docs/en/schemas/couches.svg" alt="The layers of AESTHETICS, crossed by one write, step by step: ticking a set during a workout. The app’s real folders, top to bottom. lib/features/seance: one folder per module, ten in all, each with its routes; the workout screen reads the repository and hands it every gesture through SeanceEditeur, it never opens the workout file itself. lib/core/models: objects that are copied rather than mutated, with hand-written toJson and fromJson. lib/core/data: SessionRepo, a ChangeNotifier, keeps the workout in memory, notifies listeners, then writes through Store, one JSON file per collection, all at once or not at all. seance_active.json: the workout in progress, in the app’s donnees folder, it survives closing the app. lib/core/logic: pure Dart, no screen, for dates, estimated 1RM, records, recovery and units. lib/core/theme and lib/core/ui: tokens, colours and shared components, where the dark green of a completed set comes from. lib/app: AestheticApp provides the repositories to the whole tree, through provider, and the router assembles the modules’ routes; it is not on this path. On the phone, the workout in progress: Bench press, three sets of 80 kg × 8, the first already completed; the header reads Duration 0:12:40, Volume 640 kg, Sets 1. The path, in the order of the code. 1, in green, the finger taps the tick of the second set. 2, the screen calls validerSerie(), which builds a new, completed set. 3, it hands it to SessionRepo.updateActive(). 4, in blue, the repository calls notifyListeners(). 5, the screen redraws: the row turns green, Sets 2, Volume 1,280 kg. 6, in green, the repository writes through Store.write(): a .tmp file, then a rename, and seance_active.json holds the set, weight 80, reps 8, done true. 7, in gold, once the write is finished, the screen checks for a record with Strength.oneRepMax(). 8, in blue, rest starts: the pill at the top shows 1:30. So the screen is notified before the file is written. State: provider and ChangeNotifier, with no code generation; nine repositories provided at the root, and every collection written through Store." width="100%">

Ticking a set goes through the whole app. The screen hands the action to `SessionRepo`, which keeps the workout in memory, notifies the screen, then writes it to `seance_active.json` atomically: a temporary file, then a rename. The workout in progress therefore survives the app being closed, and the screen never waits for the disk. State relies on `provider` and `ChangeNotifier`.

**The unfolded screen.** Under 600 points wide, the app stays in portrait, like a phone. Beyond that the screen rotates freely, and from 840 points the bottom bar becomes a rail on the left: the workout goes two columns, the library shows the list on the left and the exercise on the right, the history puts the calendar next to the workouts.

<a id="tests"></a>
<img src="docs/en/sections/s14.png" alt="14 The tests" width="100%">

<img src="docs/en/schemas/tests.svg" alt="The AESTHETICS tests, counted file by file. A counter climbs from 0 to 905 and a ribbon of 98 cells lights up, one cell per test file, grouped by subfolder of mobile/test: first the 92 files and 875 cases of strength training and its foundation, then, set apart, the 6 files and 30 cases of the shelved modules. These are test cases written, counted in the source text with grep, not the result of a run. Each folder lights up in turn, with what it checks and a real test name. test/seance, 18 files, 133 cases: entering sets, rest, plates, finishing and saving, sharing; for example, two taps in a row on the tick complete the set only once. test/entrainer, 15 files, 166 cases: the exercise library, routines, programs and their editors; bodyweight exercise, only the reps count. test/progres, 13 files, 193 cases: calculations, statistics, goals, the yearly summary, navigation; a workout still open counts nowhere. test/profil, 9 files, 114 cases: badges, units, measurements, photos, the profile screens; the workout in progress does not count, milestones follow the number of workouts. test/import, 8 files, 81 cases: reading CSV files, matching exercise names, duplicates; different equipment, never accepted on its own. test/aujourdhui, 8 files, 53 cases: the home screen, empty, narrow or wide, and the summary of the day; two workouts on the same day, the dot shows the first, like the calendar. test/inscription, 6 files, 16 cases: first launch, the draft, a damaged profile at the welcome screen; the created profile clears the draft, even if a save was pending. test/parcours, 4 files, 47 cases: navigation from one screen to another and end-to-end journeys; Resume reopens the workout, back minimises it without losing it. test/core, 6 files, 43 cases: number formats, the models and reading them back, equivalents; twelve set types, old names read back. test/data, 2 files, 16 cases: the exercise catalogue and storage, writes and damaged files; atomic, no temporary file is left, the content is complete. test/body, 1 file, 4 cases: the body map, with the only comparison against a reference image; every muscle in the contract has a mask on at least one view of the body. test/fondation_rendu, 2 files, 9 cases: the shared foundation, contrast, touch target sizes, rendering; secondary text passes 4.5 on the background, the card and the surface. Shelved modules, 6 files, 30 cases: test/coach, test/nutrition and test/sante, the tests of three modules hidden by default, written and counted apart. Counted, not run: calls read in the source text, 543 test( and 362 testWidgets(; eight carry a skip, three for known defects, five conditional." width="100%">

The suite holds 905 test cases written in 98 files, laid out like the code: one folder per module. 875 cover strength training and its foundation, 30 the shelved modules. These numbers are counts in the code (543 `test(` and 362 `testWidgets(`); eight cases are marked `skip`, three of them for known defects.

<a id="construire"></a>
<img src="docs/en/sections/s15.png" alt="15 Building, licences and author" width="100%">

AESTHETICS is not on the Play Store, and no APK is published here for now.

**The code.** For now this repository holds the presentation of the project: the app's code is not published here yet. It is a Flutter app, for Android 8 or later, built with one command:

```
flutter build apk --release --target-platform android-arm64
# the demo: six months of made-up workouts, in a separate data folder
flutter build apk --release --target-platform android-arm64 --dart-define=DEMO=true
```

The demo fills itself with sample data on first launch, without ever touching real data: it is the one used for the screenshots on this page.

**Licences.** The code is under the [MIT](LICENSE) licence. The rest belongs to its authors:

- **The exercises**: the catalogue, the animations, the poses and the character come from a professional pack, used under a commercial Enterprise licence that I purchased. The illustrations shown on this page are shown under that licence: they are not covered by the code's MIT licence and may not be reused.
- **The 3D objects** of the recap and the end-of-workout cards: Microsoft's [Fluent Emoji](https://github.com/microsoft/fluentui-emoji), MIT licence.
- **The badge pictograms**: [Phosphor Icons](https://phosphoricons.com), MIT licence.
- **The typefaces**: Figtree and Montserrat, SIL Open Font License 1.1.
- **The sounds** of the timer and the record: [Pixabay](https://pixabay.com), under its content licence.

Designed and written by **Tristan Joncour**, engineering student in cyber defence at ENSIBS, for his own workouts. My other apps: [SmartBudget](https://github.com/Cybertrist/SmartBudget), [BodyCount](https://github.com/Cybertrist/BodyCount), [Serenity](https://github.com/Cybertrist/Serenity).

<br>

<sub>The images on this page come from no drawing software: they are HTML pages captured by Chrome, and animated SVGs written by <code>anime.js</code> and the modules in <code>schemas/</code>. The screenshots come from an emulator, in the app's demo. Everything is in <a href="docs/tools/">docs/tools</a>.</sub>
