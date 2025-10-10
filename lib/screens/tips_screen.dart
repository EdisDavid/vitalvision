import 'package:flutter/material.dart';

class TipsScreen extends StatelessWidget {
	final String label;

	const TipsScreen({super.key, required this.label});

	@override
	Widget build(BuildContext context) {
		final tips = _tipsForLabel(label);

		return Scaffold(
			appBar: AppBar(title: const Text('Consejos de Primeros Auxilios')),
			body: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
									Text(
										'Detectado: $label',
										style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
									),
						const SizedBox(height: 12),
						Expanded(
							child: SingleChildScrollView(
								child: Text(
									tips,
									style: const TextStyle(fontSize: 16, height: 1.5),
								),
							),
						),
						ElevatedButton.icon(
							onPressed: () => Navigator.pop(context),
							icon: const Icon(Icons.arrow_back),
							label: const Text('Volver'),
						),
					],
				),
			),
		);
	}

	String _tipsForLabel(String label) {
		switch (label.toLowerCase()) {
			case 'quemaduras':
				return '''
Consejos para quemaduras:

- Enfriar inmediatamente con agua corriente fría durante al menos 10 minutos.
- No aplicar hielo directamente sobre la piel.
- Retirar anillos o prendas ajustadas si no están pegadas a la piel.
- Cubrir con un apósito limpio y no adherente.
- Buscar atención médica si la quemadura es extensa, muy dolorosa o profunda.
''';
			case 'raspones':
			case 'heridas':
			case 'heridas y sangrado':
				return '''
Consejos para heridas y raspones:

- Lavar cuidadosamente con agua y jabón suave.
- Detener el sangrado aplicando presión con una gasa limpia.
- Aplicar un antiséptico y cubrir con apósito.
- Cambiar el apósito diariamente y vigilar signos de infección.
- Buscar atención si la herida es profunda o no deja de sangrar.
''';
			default:
				return 'Consejos generales: Mantén la calma, asegúrate de que la persona esté en un lugar seguro y llama a emergencias si la situación es grave.';
		}
	}
}
