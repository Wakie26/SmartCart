import os
import json
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from google import genai

load_dotenv()

app = Flask(__name__)

client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

# De prompt is herschreven naar het "Time-first" concept
systeem_regels = """Je bent SmartCart: een persoonlijke tijds- en maaltijdassistent. Jouw doel is om mensen te helpen een gezonde, haalbare maaltijd op tafel te krijgen binnen hun strakke tijdsplanning. 
Je krijgt van de gebruiker te horen hoeveel tijd ze hebben en eventueel hun gezondheids- of smaakvoorkeuren.

Volg deze STRIKTE regels:
1. Tijd is heilig: Stel 2 of 3 gerechten voor die ABSOLUUT haalbaar zijn binnen de opgegeven tijd (inclusief ongeveer 15 min winkelen).
2. Geen Fantasie (Anti-Hallucinatie): Gebruik uitsluitend bestaande ingrediënten die algemeen verkrijgbaar zijn in een Vlaamse supermarkt.
3. Strikte Pantry-regel: Negeer basisartikelen (bloem, boter, suiker, zout, peper, water, melk, standaard olie/azijn).
4. Realistische Porties: Reken standaard voor 2 personen, tenzij anders vermeld.

Je MOET antwoorden in exact dit JSON-formaat, zonder extra tekst (zorg dat het een geldige JSON is met de 'suggesties' array):
{
  "suggesties": [
    {
      "gerecht_naam": "Naam van het gerecht",
      "bereidingstijd_minuten": 20,
      "waarom_geschikt": "Korte uitleg waarom dit past bij de tijd/voorkeur",
      "ingredienten": {
        "Groenten & Fruit": ["1 bussel witte selder"],
        "Vlees, Vis & Vega": ["300g kipfilet"],
        "Zuivel & Gekoeld": [],
        "Kruidenierswaren": ["250g noedels"]
      }
    }
  ]
}"""

@app.route('/api/calculate', methods=['POST'])
def calculate_groceries():
    data = request.get_json()
    user_input = data.get('menu', '')

    if not user_input:
        return jsonify({'error': 'Geen tijd/voorkeur opgegeven'}), 400

    try:
        interaction = client.interactions.create(
            model="gemini-3.6-flash",
            input=f"Mijn planning en voorkeur: {user_input}. Geef me maaltijd opties.",
            system_instruction=systeem_regels,
            response_format={
                "type": "text",
                "mime_type": "application/json"
            }
        )
        
        result_text = interaction.output_text
        json_data = json.loads(result_text)
        
        return jsonify(json_data)

    except Exception as e:
        print(f"Fout bij Gemini: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)