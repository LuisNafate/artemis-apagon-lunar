# gdlint: disable=max-line-length
class_name LunarScienceCards
extends RefCounted

## Fichas del archivo científico para niños de 7 a 12 años. Cada una cuenta qué pasó,
## explica las palabras de científico y aclara qué simplifica el juego. Los números salen
## de context_core/data/lunar_reference_v1.json, así que siguen siendo los de la NASA.

const MOON_KM := 384400.0
const MONTHS := [
	"enero",
	"febrero",
	"marzo",
	"abril",
	"mayo",
	"junio",
	"julio",
	"agosto",
	"septiembre",
	"octubre",
	"noviembre",
	"diciembre"
]
const MONTHS_EN := [
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December"
]
const ENGLISH := [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]


## Texto de la ficha para la campaña, o vacío si la ficha conserva su texto original.
static func text(record: Dictionary, donki_storms: bool) -> String:
	var values: Dictionary = record.get("observation", record.get("reference", {}))
	if LunarLanguage.current() == "en":
		return _english(record, values, donki_storms)
	match String(record.id):
		"donki_sep_20240510":
			if not donki_storms:
				return ""
			return _card(
				(
					(
						"El Sol a veces tiene explosiones llamadas llamaradas solares. Algunas lanzan "
						+ "partículas tan rápidas que pueden dañar a los astronautas y a las naves. "
						+ "El %s a las %s UTC (hora universal), la NASA envió la alerta %s porque esas partículas "
						+ "venían en camino."
					)
					% [
						_spanish_date(String(values.messageIssueTime)),
						String(values.messageIssueTime).substr(11, 5),
						values.messageID
					]
				),
				[
					(
						"DONKI (Database Of Notifications, Knowledge, Information): "
						+ "la base de datos de la NASA donde se anota el clima espacial."
					),
					(
						"CCMC (Community Coordinated Modeling Center): "
						+ "el centro de la NASA que estudia el clima espacial y publica las alertas."
					),
					(
						"Clase C, M o X: "
						+ "la fuerza de una llamarada. Cada letra es 10 veces más fuerte."
					),
					(
						"SEP (Solar Energetic Particles): "
						+ "partículas energéticas solares, la «lluvia» peligrosa."
					),
				],
				(
					"cada tormenta usa una llamarada real de DONKI con su fecha. No todas son "
					+ "peligrosas: entre mayo y junio de 2024 hubo 243 llamaradas y solo 16 lanzaron "
					+ "partículas. Si en la vida real tardaron poco en llegar, tienes poco tiempo para "
					+ "correr al refugio. En el juego todo pasa más rápido que en la realidad."
				)
			)
		"radlab_artemis_i_hera":
			var sample: Dictionary = values.samples[0]
			return _card(
				(
					(
						"En 2022 la nave Orion viajó alrededor de la Luna sin astronautas en la misión "
						+ "Artemis I. Llevaba sensores para medir la radiación. El %s, minutos después "
						+ "del despegue, el detector %s midió %.3f µGy/h."
					)
					% [
						_spanish_date(String(sample.timestamp_utc)),
						values.instrument_id,
						sample.absorbed_dose_rate
					]
				),
				[
					(
						"Radiación: "
						+ "energía invisible que viaja por el espacio y puede dañar el cuerpo."
					),
					(
						"HERA (Hybrid Electronic Radiation Assessor): "
						+ "el detector de radiación que lleva Orion."
					),
					"µGy/h (microgray por hora): cuánta radiación absorbe el cuerpo cada hora.",
				],
				(
					"el refugio representa el blindaje que protege a la tripulación. El juego no "
					+ "mide la radiación en grays: la representa con las alertas."
				)
			)
		"neows_2016_ft14":
			var distance := float(values.miss_distance_km)
			return _card(
				(
					(
						"El asteroide %s pasó junto a la Tierra el %s, a %.2f millones de km. "
						+ "Parece mucho, pero es unas %d veces la distancia entre la Tierra y la Luna."
					)
					% [
						values.name,
						_spanish_date(String(values.datetime_as_reported)),
						distance / 1000000.0,
						roundi(distance / MOON_KM)
					]
				),
				[
					"Asteroide: una roca que da vueltas alrededor del Sol.",
					"NEO (Near-Earth Object): objeto cercano a la Tierra.",
					(
						"NeoWs (Near Earth Object Web Service): "
						+ "el servicio de la NASA que avisa qué asteroides pasarán cerca."
					),
				],
				(
					"este dato es de la Tierra, no de la base lunar. Está aquí para que veas "
					+ "cómo la NASA vigila el espacio cercano todos los días."
				)
			)
		"tle_iss_25544":
			var derived: Dictionary = record.get("derived", {})
			return _card(
				(
					(
						"La Estación Espacial Internacional (ISS) da una vuelta a la Tierra en unos "
						+ "%.1f minutos, a unos 400 km de altura. ¡Son unas %.1f vueltas al día! "
						+ "Este cálculo usa su órbita del %s."
					)
					% [
						derived.estimated_period_minutes,
						derived.mean_motion_revs_per_day,
						_spanish_date(String(values.date))
					]
				),
				[
					"Órbita: el camino que sigue una nave alrededor de un planeta.",
					"TLE (Two-Line Element set): dos líneas de números que describen una órbita.",
					"NORAD 25544: el número de identificación de la ISS.",
				],
				(
					"en la Luna no hay una estación así. Esta ficha muestra cómo se calcula una órbita "
					+ "con datos reales. El dato viene de CelesTrak, un servicio que publica las "
					+ "órbitas de los satélites, no de la NASA."
				)
			)
		"ntrs_life_support_mass":
			return _card(
				(
					(
						"Cada astronauta necesita cada día %.2f kg de oxígeno, %.2f kg de agua para "
						+ "beber y cocinar (unos %.1f litros) y %.2f kg de comida seca. También "
						+ "exhala %.2f kg de dióxido de carbono que hay que limpiar del aire."
					)
					% [
						values.oxygen,
						values.drinking_and_food_water,
						values.drinking_and_food_water,
						values.food_solids,
						values.carbon_dioxide_produced
					]
				),
				[
					(
						"ECLSS (Environmental Control and Life Support System): "
						+ "el sistema de control ambiental y soporte vital de una nave."
					),
					"Soporte vital: todo lo que mantiene vivos a los astronautas.",
					"O₂ y CO₂: oxígeno, que respiramos, y dióxido de carbono, que exhalamos.",
				],
				(
					"en la Estación Espacial reciclan el agua y la separan para obtener oxígeno. "
					+ "Por eso en el juego el hielo se convierte en agua y el agua mantiene el aire."
				)
			)
		"ntrs_lunar_radio":
			return _card(
				(
					(
						"La Luna está a unos %s km. Las ondas de radio viajan a la velocidad de la "
						+ "luz, casi 300 000 km por segundo, así que un mensaje tarda %.2f s en llegar "
						+ "a la Tierra y %.2f s en ir y volver."
					)
					% [
						_thousands(int(values.nominal_earth_moon_distance_km)),
						values.one_way_seconds_rounded,
						values.round_trip_seconds_rounded
					]
				),
				[
					"Latencia: el tiempo que tarda un mensaje en llegar.",
					"Velocidad de la luz: lo más rápido que existe en el universo.",
					"Ida y vuelta: lo que tarda tu mensaje más la respuesta.",
				],
				(
					"cuando envías la lista de vuelo por radio, el juego espera de verdad esos "
					+ "%.2f s antes de que la Tierra conteste." % values.round_trip_seconds_rounded
				)
			)
		"nasa_lro_3d":
			return _card(
				(
					"Desde 2009, la nave LRO da vueltas alrededor de la Luna y la mide. Uno de sus "
					+ "instrumentos dispara un láser al suelo y calcula la altura de montañas y "
					+ "cráteres. Con eso se sabe dónde da más el Sol en el polo sur."
				),
				[
					"LRO (Lunar Reconnaissance Orbiter): el orbitador de reconocimiento lunar.",
					(
						"LOLA (Lunar Orbiter Laser Altimeter): "
						+ "el altímetro láser de LRO, que mide alturas."
					),
					"Polo sur lunar: la zona donde la NASA quiere aterrizar en Artemis.",
				],
				(
					"el paisaje alrededor de las bases Nobile usa alturas reales medidas por LOLA, "
					+ "y las 9 bases son regiones candidatas de verdad."
				)
			)
	return ""


## Arma una ficha: qué pasó, palabras de científico y qué simplifica el juego.
static func _card(story: String, words: Array, game: String) -> String:
	var glossary := "\n".join(words.map(func(word: String) -> String: return "• " + word))
	return "%s\n\nPalabras de científico:\n%s\n\nEn el juego: %s" % [story, glossary, game]


## "2024-05-10T13:46Z" o "2024-May-10 13:55" → "10 de mayo de 2024".
static func _spanish_date(text: String) -> String:
	var parts := text.left(text.find("-", 5) + 3).split("-")
	var month := int(parts[1]) if parts[1].is_valid_int() else ENGLISH.find(parts[1]) + 1
	return "%d de %s de %s" % [int(parts[2]), MONTHS[month - 1], parts[0]]


## 384000 → "384 000".
static func _thousands(number: int) -> String:
	var digits := str(number)
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += " "
		result += digits[index]
	return result


## Las mismas fichas en ingles: cada una conserva los numeros de la NASA.
static func _english(record: Dictionary, values: Dictionary, donki_storms: bool) -> String:
	match String(record.id):
		"donki_sep_20240510":
			if not donki_storms:
				return ""
			return _card_en(
				(
					(
						"Sometimes the Sun has explosions called solar flares. Some of them throw out "
						+ "particles so fast they can hurt astronauts and ships. On %s at %s UTC "
						+ "(universal time), NASA sent alert %s because those particles were on their way."
					)
					% [
						_english_date(String(values.messageIssueTime)),
						String(values.messageIssueTime).substr(11, 5),
						values.messageID
					]
				),
				[
					"DONKI (Database Of Notifications, Knowledge, Information): NASA's database where space weather is recorded.",
					"CCMC (Community Coordinated Modeling Center): the NASA center that studies space weather and publishes the alerts.",
					"Class C, M or X: how strong a flare is. Each letter is 10 times stronger.",
					'SEP (Solar Energetic Particles): energetic particles from the Sun, the dangerous "rain".',
				],
				(
					"each storm uses a real DONKI flare with its date. Not all of them are dangerous: "
					+ "between May and June 2024 there were 243 flares and only 16 threw out particles. "
					+ "If in real life they took little time to arrive, you have little time to run to the "
					+ "shelter. In the game everything happens faster than in reality."
				)
			)
		"radlab_artemis_i_hera":
			var sample: Dictionary = values.samples[0]
			return _card_en(
				(
					(
						"In 2022 the Orion ship flew around the Moon with no astronauts on the Artemis I "
						+ "mission. It carried sensors to measure radiation. On %s, minutes after liftoff, "
						+ "the %s detector measured %.3f µGy/h."
					)
					% [
						_english_date(String(sample.timestamp_utc)),
						values.instrument_id,
						sample.absorbed_dose_rate
					]
				),
				[
					"Radiation: invisible energy that travels through space and can harm the body.",
					"HERA (Hybrid Electronic Radiation Assessor): the radiation detector Orion carries.",
					"µGy/h (microgray per hour): how much radiation the body absorbs each hour.",
				],
				(
					"the shelter stands for the shielding that protects the crew. The game does not "
					+ "measure radiation in grays: it represents it with alerts."
				)
			)
		"neows_2016_ft14":
			var distance := float(values.miss_distance_km)
			return _card_en(
				(
					(
						"Asteroid %s passed close to Earth on %s, %.2f million km away. It sounds like a "
						+ "lot, but it is about %d times the distance between Earth and the Moon."
					)
					% [
						values.name,
						_english_date(String(values.datetime_as_reported)),
						distance / 1000000.0,
						roundi(distance / MOON_KM)
					]
				),
				[
					"Asteroid: a rock that orbits the Sun.",
					"NEO (Near-Earth Object): an object close to Earth.",
					"NeoWs (Near Earth Object Web Service): NASA's service that tells which asteroids will pass nearby.",
				],
				(
					"this data is about Earth, not the lunar base. It is here so you can see how NASA "
					+ "watches nearby space every day."
				)
			)
		"tle_iss_25544":
			var derived: Dictionary = record.get("derived", {})
			return _card_en(
				(
					(
						"The International Space Station (ISS) circles the Earth in about %.1f minutes, at "
						+ "around 400 km high. That is about %.1f laps a day! This calculation uses its orbit from %s."
					)
					% [
						derived.estimated_period_minutes,
						derived.mean_motion_revs_per_day,
						_english_date(String(values.date))
					]
				),
				[
					"Orbit: the path a ship follows around a planet.",
					"TLE (Two-Line Element set): two lines of numbers that describe an orbit.",
					"NORAD 25544: the ISS's ID number.",
				],
				(
					"there is no station like this on the Moon. This card shows how an orbit is "
					+ "calculated with real data. The data comes from CelesTrak, a service that publishes "
					+ "satellite orbits, not from NASA."
				)
			)
		"ntrs_life_support_mass":
			return _card_en(
				(
					(
						"Each astronaut needs %.2f kg of oxygen every day, %.2f kg of water to drink and "
						+ "cook (about %.1f liters) and %.2f kg of dry food. They also breathe out %.2f kg of "
						+ "carbon dioxide that must be cleaned from the air."
					)
					% [
						values.oxygen,
						values.drinking_and_food_water,
						values.drinking_and_food_water,
						values.food_solids,
						values.carbon_dioxide_produced
					]
				),
				[
					"ECLSS (Environmental Control and Life Support System): a ship's environmental control and life support system.",
					"Life support: everything that keeps astronauts alive.",
					"O₂ and CO₂: oxygen, which we breathe in, and carbon dioxide, which we breathe out.",
				],
				(
					"on the Space Station they recycle water and split it to get oxygen. That is why in "
					+ "the game ice turns into water and water keeps the air going."
				)
			)
		"ntrs_lunar_radio":
			return _card_en(
				(
					(
						"The Moon is about %s km away. Radio waves travel at the speed of light, almost "
						+ "300,000 km per second, so a message takes %.2f s to reach Earth and %.2f s to go and come back."
					)
					% [
						_thousands(int(values.nominal_earth_moon_distance_km)).replace(" ", ","),
						values.one_way_seconds_rounded,
						values.round_trip_seconds_rounded
					]
				),
				[
					"Latency: the time a message takes to arrive.",
					"Speed of light: the fastest thing in the universe.",
					"Round trip: how long your message takes plus the reply.",
				],
				(
					"when you send the flight checklist by radio, the game really waits those "
					+ "%.2f s before Earth answers." % values.round_trip_seconds_rounded
				)
			)
		"nasa_lro_3d":
			return _card_en(
				(
					"Since 2009, the LRO ship has been orbiting the Moon and measuring it. One of its "
					+ "instruments fires a laser at the ground and works out the height of mountains and "
					+ "craters. With that we know where the Sun shines most at the south pole."
				),
				[
					"LRO (Lunar Reconnaissance Orbiter): the lunar reconnaissance orbiter.",
					"LOLA (Lunar Orbiter Laser Altimeter): LRO's laser altimeter, which measures heights.",
					"Lunar south pole: the area where NASA wants to land on Artemis.",
				],
				(
					"the landscape around the Nobile bases uses real heights measured by LOLA, and the "
					+ "9 bases are real candidate regions."
				)
			)
	return ""


static func _card_en(story: String, words: Array, game: String) -> String:
	var glossary := "\n".join(words.map(func(word: String) -> String: return "• " + word))
	return "%s\n\nScientist words:\n%s\n\nIn the game: %s" % [story, glossary, game]


## "2024-05-10T13:46Z" o "2024-May-10 13:55" -> "May 10, 2024".
static func _english_date(text: String) -> String:
	var parts := text.left(text.find("-", 5) + 3).split("-")
	var month := int(parts[1]) if parts[1].is_valid_int() else ENGLISH.find(parts[1]) + 1
	return "%s %d, %s" % [MONTHS_EN[month - 1], int(parts[2]), parts[0]]
