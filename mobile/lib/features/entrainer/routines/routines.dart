/// Module routines et programmes : widgets et fonctions réutilisables.
library;

export '../commun/carte_jour.dart' show CarteJour;
export 'logic/demarrer.dart' show demarrerRoutine, routinePrevue;
export 'logic/idees.dart' show IdeeProgramme, ideesProgrammes, ideesClassiques, ideesRecommandees, sigleProgramme;
export 'logic/program_plan.dart' show ProgramPlan, ProgramPlanRepo, ProgressionType;
export 'logic/program_templates.dart' show modelesProgrammes, ModeleProgramme, creerProgrammeDepuisModele;
export 'logic/routine_stats.dart' show resumeRoutine, routineEnTexte, seriesParMuscle, intensitesPour;
export 'logic/suggestion.dart' show SuggestionRoutine, suggererRoutine, raisonSuggestion, titreSuggestion, derniereFois;
export 'logic/vignettes.dart' show RoutinePrefs, VignetteRoutine, jourDeVignette;
export 'routines_routes.dart' show routinesSubRoutes;
export 'widgets/ligne_routine.dart' show LigneRoutine, VignetteRoutineVue, lancerRoutine, montrerActionsRoutine;
