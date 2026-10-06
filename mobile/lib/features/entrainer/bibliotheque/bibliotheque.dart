/// Bibliothèque d'exercices : ce que les autres modules peuvent utiliser.
library;

export 'bibliotheque_routes.dart' show bibliothequeSubRoutes;
export 'logic/exercise_index.dart' show LibraryFilters, LibraryScope, LibrarySort, frequencesExercices;
export 'logic/exercise_stats.dart' show ExerciseStats, StatMetric, StatPeriod, SessionPoint, RecordLine;
export 'logic/records.dart' show TypeRecord, RecordFiche, recordsDe, progressionRecord;
export 'pages/exercise_actions.dart' show ExerciseActions;
export 'pages/exercise_detail_page.dart' show ouvrirFicheExercice, FicheTab, ExerciseDetailPage, ExerciseDetailView;
export 'pages/exercise_edit_page.dart' show ExerciseEditPage;
export 'pages/library_page.dart' show ExerciseLibraryPage;
export 'pages/muscles_page.dart' show MusclesPage, ChiffresMuscle, chiffresDuMuscle;
export 'pages/picker_page.dart' show pickExercises, pickExercise, choisirExercices, ExercisePickerPage;
export 'widgets/exercise_media.dart' show ExerciseThumb, ExerciseTile, ExerciseMediaView, ExerciseVideo, mediaImage;
export 'widgets/muscle_pickers.dart' show FittedBodyDual, MuscleLegend, MuscleFilterPage;
