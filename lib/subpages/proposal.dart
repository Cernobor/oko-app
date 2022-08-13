import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';

class CreateProposal extends StatefulWidget {
  const CreateProposal({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CreateProposalState();
}

class _CreateProposalState extends State<CreateProposal> {
  final TextEditingController descriptionInputController =
      TextEditingController();
  final TextEditingController howInputController = TextEditingController();

  String? descriptionInputError;
  String? howInputError;

  @override
  void initState() {
    super.initState();
    descriptionInputController.text = '';
    howInputController.text = '';
  }

  @override
  Widget build(BuildContext context) {
    if (descriptionInputController.text.isNotEmpty) {
      descriptionInputError = null;
    } else {
      descriptionInputError = I18N.of(context).errorProposalDescriptionRequired;
    }
    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(I18N.of(context).proposeImprovement),
            primary: true,
            leading: BackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: I18N.of(context).dialogSave,
                onPressed: _isValid() ? _save : null,
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              verticalDirection: VerticalDirection.down,
              children: [
                Text(I18N.of(context).suggestionInfo),
                TextField(
                  controller: descriptionInputController,
                  keyboardAppearance: Theme.of(context).brightness,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                      labelText: I18N.of(context).proposalDescriptionLabel,
                      errorText: descriptionInputError),
                  maxLines: null,
                  onChanged: (String value) {
                    setState(() {
                      if (value.isEmpty) {
                        descriptionInputError =
                            I18N.of(context).errorProposalDescriptionRequired;
                      } else {
                        descriptionInputError = null;
                      }
                    });
                  },
                ),
                TextField(
                  controller: howInputController,
                  keyboardAppearance: Theme.of(context).brightness,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: I18N.of(context).proposalHowLabel,
                    errorText: howInputError,
                  ),
                  maxLines: null,
                  onChanged: (String value) {
                    setState(() {
                      if (value.isEmpty) {
                        howInputError =
                            I18N.of(context).errorProposalHowRequired;
                      } else {
                        howInputError = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ));
  }

  bool _isValid() {
    return descriptionInputController.text.isNotEmpty &&
        howInputController.text.isNotEmpty;
  }

  void _save() {
    Navigator.of(context).pop(
        Proposal(0, descriptionInputController.text, howInputController.text));
  }

  @override
  void dispose() {
    descriptionInputController.dispose();
    howInputController.dispose();
    super.dispose();
  }
}
