import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

// Define hazard types and their half-lives (in days)
const HAZARD_HALF_LIVES: Record<string, number> = {
  'flood': 7,        // Flood hazards decay quickly
  'landslide': 14,   // Landslide hazards last longer
  'construction': 3, // Construction hazards decay very fast
  'accident': 2,     // Accident hazards are immediate/temporary
  'weather': 1,      // Weather-related hazards decay very fast
  'default': 10      // Default half-life for unknown types
};

serve(async (req) => {
  try {
    // Get all hazards that are not in clear/impassable status (these don't decay)
    const { data: hazards, error: fetchError } = await supabase
      .from('hazards')
      .select('id, hazard_type, confidence, timestamp')
      .not('status', 'in', ['clear', 'impassable']);

    if (fetchError) throw fetchError;

    const now = new Date();
    const updatedHazards = [];

    for (const hazard of hazards) {
      // Calculate time elapsed since hazard was reported
      const hazardTime = new Date(hazard.timestamp);
      const timeDiffDays = (now.getTime() - hazardTime.getTime()) / (1000 * 60 * 60 * 24);

      // Get half-life for this hazard type (default to 10 days if unknown)
      const halfLife = HAZARD_HALF_LIVES[hazard.hazard_type] || HAZARD_HALF_LIVES['default'];

      // Apply time decay formula: confidence = initial_confidence * (0.5 ^ (timeElapsed / halfLife))
      // We'll use the original confidence as 100 for decay calculation, then blend with current
      const decayFactor = Math.pow(0.5, timeDiffDays / halfLife);
      const decayedConfidence = 100 * decayFactor;

      // Blend decayed confidence with current confidence (70% decayed, 30% current to avoid abrupt changes)
      const newConfidence = Math.round(0.7 * decayedConfidence + 0.3 * hazard.confidence);

      // Determine new status based on confidence
      let newStatus: string;
      if (newConfidence >= 80) {
        newStatus = 'clear';
      } else if (newConfidence >= 60) {
        newStatus = 'partial';
      } else if (newConfidence >= 40) {
        newStatus = 'uncertain';
      } else if (newConfidence >= 20) {
        newStatus = 'impassable';
      } else {
        newStatus = 'impassable';
      }

      // Only update if status actually changed
      if (newStatus !== hazard.status) {
        const { error: updateError } = await supabase
          .from('hazards')
          .update({
            confidence: newConfidence,
            status: newStatus,
            updated_at: new Date().toISOString()
          })
          .eq('id', hazard.id);

        if (!updateError) {
          updatedHazards.push({
            id: hazard.id,
            oldConfidence: hazard.confidence,
            newConfidence,
            oldStatus: hazard.status,
            newStatus
          });
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Time decay executed successfully. Updated ${updatedHazards.length} hazards.`,
        data: updatedHazards
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in timeDecay function:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});