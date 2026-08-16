import os
import json
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from google import genai

load_dotenv()

app = Flask(__name__)

client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

systeem_regels = """Je bent SmartCart: een persoonlijke tijds- en maaltijdassistent. Jouw doel is om mensen te helpen een gezonde, haalbare maaltijd op tafel te krijgen binnen hun strakke tijdsplanning. 

Volg deze STRIKTE regels:
1. Tijd is heilig: Je krijgt te horen wat de wens van de gebruiker is én hoeveel minuten de logistiek (rijden en winkelen) kost. De bereidingstijd van je gerechten mag ABSOLUUT NIET langer zijn dan de tijd die overblijft in de planning van de gebruiker.
2. Geen Fantasie (Anti-Hallucinatie): Gebruik uitsluitend bestaande ingrediënten die algemeen verkrijgbaar zijn in een Vlaamse supermarkt.
3. Strikte Pantry-regel: Negeer basisartikelen (bloem, boter, suiker, zout, peper, water, melk, standaard olie/azijn).
4. Realistische Porties: Reken standaard voor 2 personen, tenzij anders vermeld.

Je MOET antwoorden in exact dit JSON-formaat, zonder extra tekst:
{
  "suggesties": [
    {
      "gerecht_naam": "Naam van het gerecht",
      "bereidingstijd_minuten": 20,
      "waarom_geschikt": "Korte uitleg waarom dit past bij de resterende kooktijd en voorkeur",
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
    reistijd = data.get('reistijd_minuten', 0)

    if not user_input:
        return jsonify({'error': 'Geen tijd/voorkeur opgegeven'}), 400

    try:
        # We bouwen een onzichtbare prompt die de berekende reistijd meeneemt
        ai_prompt = f"De wens van de gebruiker: '{user_input}'. LET OP: De gebruiker is al {reistijd} minuten kwijt aan de rit naar de supermarkt, het winkelen zelf, en de rit naar huis. Zorg dat de 'bereidingstijd_minuten' van jouw suggesties haalbaar is in de tijd die overblijft!"

        interaction = client.interactions.create(
            model="gemini-3.6-flash",
            input=ai_prompt,
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