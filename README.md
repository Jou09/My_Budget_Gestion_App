# Mon Budget Étudiant

Application Flutter hors ligne pour suivre les revenus, les dépenses quotidiennes et les charges mensuelles fixes en ariary malgache (MGA).

## Fonctions

- Code PIN demandé à la première ouverture et à chaque retour dans l’application ; le code est conservé dans le coffre sécurisé Android.
- Revenus et dépenses avec description, catégorie, date et montant en ariary.
- Charges fixes récurrentes, échéance mensuelle et action « Marquer payé » sans double comptage.
- Solde disponible calculé après les dépenses enregistrées et les charges fixes encore dues.
- Historique filtré par mois et résumé des dépenses du jour.
- Données enregistrées localement dans la base privée de l’application, sans compte ni connexion réseau.

## Android

La version minimale demandée est Android 7.0 (API 24). Depuis ce dossier :

```sh
flutter pub get
flutter build apk --release
```

L’APK sera produit dans `build/app/outputs/flutter-apk/app-release.apk`.
