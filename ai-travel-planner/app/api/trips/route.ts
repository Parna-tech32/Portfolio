import { GoogleGenAI, Type } from "@google/genai";
import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

export async function POST(request: Request) {
  try {
    const supabase = await createClient();

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return NextResponse.json(
        {
          error: "You must be logged in.",
        },
        { status: 401 }
      );
    }

    // ================================
    // GET FORM DATA
    // ================================

    const body = await request.json();

    const {
      destination,
      budget,
      days,
    } = body;

    // ================================
    // VALIDATE INPUT
    // ================================

    if (!destination || !budget || !days) {
      return NextResponse.json(
        {
          error: "Destination, budget and days are required.",
        },
        { status: 400 }
      );
    }

    // ================================
    // PROMPT
    // ================================

const prompt = `
Create a personalized travel itinerary for:

Destination: ${destination}
Budget: ${budget}
Number of days: ${days}

IMPORTANT:
The itinerary must prioritize the MOST IMPORTANT and POPULAR attractions of the destination.
Do not create an itinerary that focuses only on the main city.

For Kashmir specifically, treat these as HIGH-PRIORITY destinations:
1. Srinagar
2. Gulmarg
3. Sonmarg
4. Pahalgam

Other attractions such as Doodhpathri, Yusmarg, Mughal Gardens, Dal Lake, Shikara Ride,
Nishat Bagh, Shalimar Bagh, Pari Mahal, Hazratbal Shrine and local markets can be included
after the high-priority destinations have been covered.

For a trip of 4-5 days:
- Make sure Sonmarg is included.
- Make sure Gulmarg is included.
- Make sure Pahalgam is included if the number of days allows.
- Include Srinagar and Dal Lake.
- Do NOT spend most of the trip only inside Srinagar.
- Group geographically nearby places together to reduce unnecessary travel.
- If there are too few days to visit everything, prioritize the major destinations
  rather than filling the itinerary with minor attractions.

For longer trips:
- Include all major destinations first.
- Then add secondary attractions and local experiences.
- Avoid repeating the same type of sightseeing unnecessarily.

GENERAL REQUIREMENTS:

- Create exactly ${days} days.
- Make the itinerary realistic and practical.
- Consider the given budget of ${budget}.
- Include sightseeing every day.
- Include useful activities every day.
- Include BREAKFAST, LUNCH, and DINNER for EVERY SINGLE DAY.
- Every breakfast, lunch, and dinner must include a real restaurant or food place.
- Every restaurant must include its name and location.
- Keep restaurants reasonably close to that day's activities.
- Consider the given budget when choosing restaurants.
- Include a mixture of affordable local food and popular restaurants.
- Include local/specialty foods where appropriate.
- Give an approximate meal cost.
- Do not repeat the same restaurant unless absolutely necessary.

ACTIVITY INFORMATION:

For EVERY activity provide:
- name
- short description
- exact location
- approximate time required to visit
- entry fee

For entry fees:
- If the attraction is free, write "Free".
- If an entry ticket is normally required, provide a realistic approximate fee.
- For activities such as gondola rides, boat rides, cable cars, etc.,
  clearly mention the approximate activity cost.
- Do not invent obviously impossible prices.

TRAVEL PLANNING:

- Consider realistic travel time between destinations.
- Do not put places that are very far apart on the same day unless it is genuinely practical.
- Group nearby attractions together.
- For destinations such as Gulmarg, Sonmarg and Pahalgam, allow enough time
  for travel and sightseeing.
- Do not overload a single day.
- Give the user enough time to actually enjoy each location.
- Prioritize experience quality over adding a large number of attractions.

KASHMIR PRIORITY RULE:

If the destination is Kashmir, Srinagar, Jammu and Kashmir, or a similar Kashmir
travel request, prioritize the following order:

HIGH PRIORITY:
- Srinagar
- Sonmarg
- Gulmarg
- Pahalgam

MEDIUM PRIORITY:
- Dal Lake / Shikara Ride
- Mughal Gardens
- Nishat Bagh
- Shalimar Bagh
- Pari Mahal
- Hazratbal Shrine
- Local Srinagar markets

OPTIONAL / LOWER PRIORITY:
- Doodhpathri
- Yusmarg
- Other less important attractions

Do not replace a HIGH PRIORITY destination with a lower-priority attraction
unless there is a genuine practical reason.

For example, for a 5-day Kashmir trip, a good structure could be approximately:

Day 1: Srinagar + Dal Lake / Shikara
Day 2: Gulmarg
Day 3: Sonmarg
Day 4: Pahalgam
Day 5: Srinagar + remaining important attractions

You may adjust this structure if necessary based on travel time, weather,
budget and practicality.

IMPORTANT:
Do not blindly follow the example schedule if it creates unrealistic travel.
Use your judgment while ensuring the major destinations are covered.

Do not use markdown.
Return ONLY valid JSON.

Return the itinerary in exactly this JSON structure:

{
  "destination": "${destination}",
  "days": [
    {
      "day": 1,
      "title": "Day title",
      "activities": [
        {
          "name": "Activity name",
          "description": "Short description",
          "location": "Exact location or address",
          "duration": "Approximate time required to visit",
          "entry_fee": "Entry fee or Free"
        }
      ],
      "meals": {
        "breakfast": {
          "restaurant": "Real restaurant name",
          "dish": "Recommended dish",
          "location": "Exact restaurant location",
          "estimated_cost": "Approximate cost per person"
        },
        "lunch": {
          "restaurant": "Real restaurant name",
          "dish": "Recommended dish",
          "location": "Exact restaurant location",
          "estimated_cost": "Approximate cost per person"
        },
        "dinner": {
          "restaurant": "Real restaurant name",
          "dish": "Recommended dish",
          "location": "Exact restaurant location",
          "estimated_cost": "Approximate cost per person"
        }
      }
    }
  ]
}
`;

    console.log(
      "Gemini key exists:",
      !!process.env.GEMINI_API_KEY
    );

    // ================================
    // GEMINI STRUCTURED OUTPUT
    // ================================

    const response = await ai.models.generateContent({
      model: "gemini-3.6-flash",

      contents: prompt,

      config: {
        responseMimeType: "application/json",

        responseSchema: {
          type: Type.OBJECT,

          properties: {
            destination: {
              type: Type.STRING,
            },

            days: {
              type: Type.ARRAY,

              items: {
                type: Type.OBJECT,

                properties: {
                  day: {
                    type: Type.INTEGER,
                  },

                  title: {
                    type: Type.STRING,
                  },

                  activities: {
                    type: Type.ARRAY,

                    items: {
                      type: Type.OBJECT,

                      properties: {
                        name: {
                          type: Type.STRING,
                        },

                        description: {
                          type: Type.STRING,
                        },

                        location: {
                          type: Type.STRING,
                        },
                      },

                      required: [
                        "name",
                        "description",
                        "location",
                      ],
                    },
                  },

                  meals: {
                    type: Type.OBJECT,

                    properties: {
                      breakfast: {
                        type: Type.OBJECT,

                        properties: {
                          restaurant: {
                            type: Type.STRING,
                          },

                          dish: {
                            type: Type.STRING,
                          },

                          location: {
                            type: Type.STRING,
                          },

                          estimated_cost: {
                            type: Type.STRING,
                          },
                        },

                        required: [
                          "restaurant",
                          "dish",
                          "location",
                          "estimated_cost",
                        ],
                      },

                      lunch: {
                        type: Type.OBJECT,

                        properties: {
                          restaurant: {
                            type: Type.STRING,
                          },

                          dish: {
                            type: Type.STRING,
                          },

                          location: {
                            type: Type.STRING,
                          },

                          estimated_cost: {
                            type: Type.STRING,
                          },
                        },

                        required: [
                          "restaurant",
                          "dish",
                          "location",
                          "estimated_cost",
                        ],
                      },

                      dinner: {
                        type: Type.OBJECT,

                        properties: {
                          restaurant: {
                            type: Type.STRING,
                          },

                          dish: {
                            type: Type.STRING,
                          },

                          location: {
                            type: Type.STRING,
                          },

                          estimated_cost: {
                            type: Type.STRING,
                          },
                        },

                        required: [
                          "restaurant",
                          "dish",
                          "location",
                          "estimated_cost",
                        ],
                      },
                    },

                    required: [
                      "breakfast",
                      "lunch",
                      "dinner",
                    ],
                  },
                },

                required: [
                  "day",
                  "title",
                  "activities",
                  "meals",
                ],
              },
            },
          },

          required: [
            "destination",
            "days",
          ],
        },
      },
    });

    // ================================
    // GET GEMINI OUTPUT
    // ================================

    const output = response.text;

    if (!output) {
      return NextResponse.json(
        {
          error: "Gemini returned an empty response.",
        },
        { status: 500 }
      );
    }

    console.log("Gemini output received.");

    // ================================
    // PARSE JSON
    // ================================

    let itinerary;

    try {
      itinerary = JSON.parse(output);
    } catch (parseError) {
      console.error(
        "JSON parsing error:",
        parseError
      );

      console.error(
        "Gemini output:",
        output
      );

      return NextResponse.json(
        {
          error:
            "Gemini returned invalid itinerary data.",
        },
        { status: 500 }
      );
    }

    // ================================
    // EXTRA VALIDATION
    // ================================

    if (
      !itinerary.days ||
      itinerary.days.length !== Number(days)
    ) {
      return NextResponse.json(
        {
          error:
            "Gemini did not generate the requested number of days.",
        },
        { status: 500 }
      );
    }

    // Make absolutely sure every day has meals.
    for (const day of itinerary.days) {
      if (
        !day.meals ||
        !day.meals.breakfast ||
        !day.meals.lunch ||
        !day.meals.dinner
      ) {
        return NextResponse.json(
          {
            error:
              "Generated itinerary is missing breakfast, lunch, or dinner.",
          },
          { status: 500 }
        );
      }
    }

    // ================================
    // SAVE TRIP TO SUPABASE
    // ================================

    const {
      data,
      error,
    } = await supabase
      .from("trips")
      .insert({
        user_id: user.id,

        title: `${destination} Trip`,

        destination,

        budget: Number(budget),

        days: Number(days),

        itinerary,
      })
      .select()
      .single();

    // ================================
    // SUPABASE ERROR
    // ================================

    if (error) {
      console.error(
        "Supabase insert error:",
        error
      );

      return NextResponse.json(
        {
          error: error.message,
        },
        { status: 500 }
      );
    }

    // ================================
    // SUCCESS
    // ================================

    return NextResponse.json({
      success: true,
      trip: data,
    });

  } catch (error) {

    console.error(
      "Trip generation error:",
      error
    );

    return NextResponse.json(
      {
        error: "Failed to generate trip.",
      },
      { status: 500 }
    );
  }
}