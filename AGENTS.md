# UI preferences

- On phones, use the shortest clear labels. Avoid repeated names, explanatory phrases in menus, and duplicate elevations in storey tabs.
- This app is multilingual. Put all product UI words, including default preset labels, descriptions and tooltips, in the existing ARB localization system for every supported language. Do not hardcode language checks or translated strings in widgets or model catalogs. User-entered names and numeric/unit symbols are not translations.
- Treat localization as a standing user requirement: every new or changed UI label must use an ARB message in every supported language, including temporary controls and category names. Check this before finishing UI work.
- Do not derive UI labels by splitting or replacing translated text. Use ARB messages or dedicated localized labels.
- Keep detailed guidance in tooltips or help; preserve space for the drawing.

# Collaboration preferences

- Tell the user when a requested correction appears illogical, unusually inconsistent, or incorrect. Explain the concrete issue and suggest a sensible alternative before implementing that part.
