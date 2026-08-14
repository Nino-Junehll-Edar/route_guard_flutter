import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

serve(async (req) => {
  try {
    // Parse the request body
    const { hazardId, action, reporterId } = await req.json();

    if (!hazardId || !action || !reporterId) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters: hazardId, action, reporterId' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Get the hazard and reporter reputation
    const { data: hazard, error: hazardError } = await supabase
      .from('hazards')
      .select('*')
      .eq('id', hazardId)
      .single();

    if (hazardError) throw hazardError;

    const { data: reporter, error: reporterError } = await supabase
      .from('user_profiles')
      .select('reputation')
      .eq('id', reporterId)
      .single();

    if (reporterError) throw reporterError;

    // Calculate reputation change based on action
    let reputationChange = 0;
    if (action === 'confirm') {
      reputationChange = 2; // Confirming a hazard gives +2 reputation
    } else if (action === 'deny') {
      reputationChange = -1; // Denying a hazard gives -1 reputation
    }

    // Update reporter reputation
    const newReputation = Math.max(0, reporter.reputation + reputationChange);
    const { error: updateError } = await supabase
      .from('user_profiles')
      .update({ reputation: newReputation })
      .eq('id', reporterId);

    if (updateError) throw updateError;

    // Update hazard confidence and weighted confirms/denies
    const confidenceUpdate = action === 'confirm' ? 10 : -5;
    const newConfidence = Math.max(0, Math.min(100, hazard.confidence + confidenceUpdate));

    const updates: any = {
      confidence: newConfidence,
      updated_at: new Date().toISOString()
    };

    if (action === 'confirm') {
      updates.weighted_confirms = hazard.weighted_confirms + 1;
    } else if (action === 'deny') {
      updates.weighted_denies = hazard.weighted_denies + 1;
    }

    // Determine new status based on confidence
    if (newConfidence >= 80) {
      updates.status = 'clear';
    } else if (newConfidence >= 60) {
      updates.status = 'partial';
    } else if (newConfidence >= 40) {
      updates.status = 'uncertain';
    } else if (newConfidence >= 20) {
      updates.status = 'impassable';
    } else {
      updates.status = 'impassable'; // Very low confidence means definitely impassable
    }

    const { error: hazardUpdateError } = await supabase
      .from('hazards')
      .update(updates)
      .eq('id', hazardId);

    if (hazardUpdateError) throw hazardUpdateError;

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Reputation and hazard status updated',
        data: {
          reputation: newReputation,
          hazardConfidence: newConfidence,
          hazardStatus: updates.status
        }
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in reputationAlgorithm function:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});