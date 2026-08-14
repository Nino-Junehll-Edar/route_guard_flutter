import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

serve(async (req) => {
  try {
    // Parse the request body
    const { hazardId } = await req.json();

    if (!hazardId) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameter: hazardId' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Get the hazard
    const { data: hazard, error: hazardError } = await supabase
      .from('hazards')
      .select('*')
      .eq('id', hazardId)
      .single();

    if (hazardError) throw hazardError;

    // Determine new status based on confidence and weighted votes
    const confidence = hazard.confidence;
    const weightedConfirms = hazard.weighted_confirms || 0;
    const weightedDenies = hazard.weighted_denies || 0;
    const totalVotes = weightedConfirms + weightedDenies;

    let newStatus = hazard.status; // Start with current status

    // Logic for determining status:
    // 1. High confidence (>80) and more confirms than denies -> clear
    // 2. Medium confidence (60-80) -> partial
    // 3. Low confidence (<40) or more denies than confirms -> impassable
    // 4. Medium-low confidence (40-60) -> uncertain

    if (confidence >= 80 && weightedConfirms > weightedDenies) {
      newStatus = 'clear';
    } else if (confidence >= 60) {
      newStatus = 'partial';
    } else if (confidence >= 40) {
      newStatus = 'uncertain';
    } else {
      newStatus = 'impassable';
    }

    // Additional logic: if there are significant denies, lean towards impassable
    if (totalVotes > 0) {
      const denyRatio = weightedDenies / totalVotes;
      if (denyRatio > 0.6 && confidence < 70) {
        newStatus = 'impassable';
      }
    }

    // Only update if status changed
    if (newStatus !== hazard.status) {
      const { error: updateError } = await supabase
        .from('hazards')
        .update({
          status: newStatus,
          updated_at: new Date().toISOString()
        })
        .eq('id', hazardId);

      if (updateError) throw updateError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Hazard status determined and updated',
        data: {
          hazardId,
          oldStatus: hazard.status,
          newStatus,
          confidence,
          weightedConfirms,
          weightedDenies
        }
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in hazardStatus function:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});