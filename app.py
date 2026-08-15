import os
import json
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()

app = Flask(__name__)

client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

systeem_regels = """Je bent een uiterst nauwkeurige, no-nonsense boodschappen-assistent voor een Vlaamse supermarkt. Je verzint NOOIT ingrediënten en baseert je uitsluitend op authentieke, bestaande recepten.

            Volg deze STRIKTE regels om hallucinaties te voorkomen:
            1. Geen Fantasie (Anti-Hallucinatie): Gebruik uitsluitend ingrediënten die daadwerkelijk bestaan en algemeen verkrijgbaar zijn in een standaard supermarkt in Vlaanderen.
            2. Gekozen Gerecht: Bij een vage term, kies jij een specifiek, bestaand klassiek gerecht en benoem je dit.
            3. Strikte Pantry-regel: Negeer basisartikelen. Zet NOOIT de volgende producten op de lijst: bloem, boter, suiker, zout, peper, water, melk, en standaard olie of azijn.
            4. Realistische Porties: Reken standaard voor 2 tot 4 personen. Gebruik logische supermarktverpakkingen (bijv. '1 netje ajuinen', '800g varkensstoofvlees').
            5. Categorisatie: Deel de ingrediënten in per supermarktafdeling.

            Je MOET antwoorden in dit exacte JSON-formaat, zonder enige extra tekst of uitleg:
            {
            "gekozen_gerecht": "Naam van het gerecht",
            "ingredienten": {
                "Groenten & Fruit": ["1 bussel witte selder"],
                "Vlees, Vis & Vega": ["800g varkensstoofvlees"],
                "Zuivel & Gekoeld": [],
                "Kruidenierswaren": ["1 flesje donker tafelbier"]
            }
            }"""

@app.route('/api/calculate', methods=['POST'])
def calculate_groceries():
    data = request.get_json()
    user_input = data.get('menu', '')

    if not user_input:
        return jsonify({'error': 'Geen menu opgegeven'}), 400

    try:
        # Volledig overgestapt op de Interactions API
        interaction = client.interactions.create(
            model="gemini-3.6-flash",
            input=user_input,
            config=types.GenerateContentConfig(
                system_instruction=systeem_regels,
                response_mime_type="application/json"
            )
        )
        
        # Gebruik de nieuwe property 'output_text'
        result_text = interaction.output_text
        
        json_data = json.loads(result_text)
        
        json_data['route_info'] = "Vertrek Bierbeek -> Colruyt -> Thuis"
        json_data['total_price'] = "Wordt later berekend"
        
        return jsonify(json_data)

    except Exception as e:
        print(f"Fout bij Gemini: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)