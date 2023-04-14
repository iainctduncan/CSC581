#include "ext.h"			// standard Max include, always required (except in Jitter)
#include "ext_obex.h"		// required for "new" style objects
#include "z_dsp.h"			// required for MSP objects
#include <math.h>

#define OSC_TABLE_SIZE 8192
#define NUM_OPS 4
#define NUM_ENVS 4
#define NUM_LFOS 4

// synth states (from note messages)
#define SYN_ON 0
#define SYN_REL 1
#define SYN_OFF

// envelope states
#define ENV_OFF 0
#define ENV_INIT 1
#define ENV_ATT 2
#define ENV_DEC 3
#define ENV_SUS 4
#define ENV_REL 5

// env modes
#define ENV_RTZ 0
#define ENV_TAKEOVER 1
#define ENV_LEGATO 2

// lfo shapes, modes, and states
#define LFO_SINE 0
#define LFO_TRI  1
#define LFO_SYNC 0
#define LFO_FREE 1
#define LFO_INIT 0  // first pass on a sync lfo
#define LFO_ON   1  // subsequent 

// struct to represent the object's state
typedef struct _fm4op {
	t_pxobject		ob;			    // the object itself (t_pxobject in MSP instead of t_object)
  long          inlet_num;  // for proxies
  void          *proxy;
  double        gain;
  double        base_frq;              // base frequency against which the multiples are applied
	double			  op_ratio[NUM_OPS]; 	   // freq for the sine
  double        op_phase[NUM_OPS];     // phasor for the operator
  double        op_amount[NUM_OPS];    // mod amount in radians
  double        op_tune[NUM_OPS];      // TODO: detune amount in cents
  // vars for operators post mod
  double        op_amount_final[NUM_OPS];    
  double        op_tune_final[NUM_OPS];      

  // last note num and vel in
  int           note_num;
  double        note_frq;
  int           vel;

  // env values 
  double        env_att[NUM_ENVS];
  double        env_dec[NUM_ENVS];
  double        env_sus[NUM_ENVS];
  double        env_rel[NUM_ENVS];
  double        env_att_inc[NUM_ENVS];
  double        env_dec_inc[NUM_ENVS];
  double        env_rel_inc[NUM_ENVS];
  double        env_out[NUM_ENVS];
  int           env_state[NUM_ENVS];
  int           env_mode[NUM_ENVS];

  // lfo values
  double        lfo_frq[NUM_LFOS];
  double        lfo_phase[NUM_LFOS];     
  double        lfo_out[NUM_LFOS];
  double        lfo_phase_inc[NUM_LFOS];
  int           lfo_shape[NUM_LFOS];  
  int           lfo_state[NUM_LFOS];
  int           lfo_mode[NUM_LFOS];

  int           syn_state;  // SYN_ON, SYN_REL, or SYN_OFF

  // not sure how we will implement the mod matrix for real, this is not very flexible
  double        env_to_tune[NUM_ENVS];
  double        env_to_mod[NUM_ENVS];
  double        lfo_to_tune[NUM_LFOS];
  double        lfo_to_mod[NUM_LFOS];
  double        vel_to_mod[NUM_OPS];

} t_fm4op;

double sine_table[OSC_TABLE_SIZE];
double triangle_table[OSC_TABLE_SIZE];
long sr;

// method prototypes
void *fm4op_new(t_symbol *s, long argc, t_atom *argv);
void fm4op_free(t_fm4op *x);
void fm4op_assist(t_fm4op *x, void *b, long m, long a, char *s);
//void fm4op_float(t_fm4op *x, double f);
//void fm4op_int(t_fm4op *x, long n);
void fm4op_dsp64(t_fm4op *x, t_object *dsp64, short *count, double samplerate, long maxvectorsize, long flags);
void fm4op_perform64(t_fm4op *x, t_object *dsp64, double **ins, long numins, double **outs, long numouts, long sampleframes, long flags, void *userparam);

void fm4op_noteon(t_fm4op *x, t_symbol *s, long ac, t_atom *av);
void fm4op_noteoff(t_fm4op *x, t_symbol *s, long ac, t_atom *av);
void fm4op_set(t_fm4op *x, t_symbol *s, long ac, t_atom *av);
void fm4op_setattr(t_fm4op *x, t_symbol *attr, double value);

// render an operator for one sample
double fm4op_render_op(t_fm4op *x, int op);
double fm4op_render_env(t_fm4op *x, int env);
double fm4op_render_lfo(t_fm4op *x, int lfo);
double fm4op_render_mod_matrix(t_fm4op *x);

//void fm4op_in1(t_fm4op *x, double f);
double fm4op_vel_to_amp(t_fm4op *x, int vel);

// global class pointer variable
static t_class *fm4op_class = NULL;

//***********************************************************************************************
// DSP helpers
void fm4op_init_sine_table(){
  for(int i=0; i < OSC_TABLE_SIZE; i++){
    sine_table[i] = sin( ((2 * M_PI) / OSC_TABLE_SIZE ) * i);
  }
}

//***********************************************************************************************
void ext_main(void *r)
{
	// object initialization, note the use of dsp_free for the freemethod, which is required
	// unless you need to free allocated memory, in which case you should call dsp_free from
	// your custom free function.

	t_class *c = class_new("fm4op~", (method)fm4op_new, (method)dsp_free, (long)sizeof(t_fm4op), 0L, A_GIMME, 0);

	//class_addmethod(c, (method)fm4op_float, "float",	A_FLOAT, 0);
	//class_addmethod(c, (method)fm4op_int, "int",	A_LONG, 0);
	class_addmethod(c, (method)fm4op_dsp64,	"dsp64",	A_CANT, 0);
	class_addmethod(c, (method)fm4op_assist, "assist",	A_CANT, 0);

  class_addmethod(c, (method)fm4op_noteon, "noteon", A_GIMME, 0);
  class_addmethod(c, (method)fm4op_noteoff,	"noteoff", A_GIMME, 0);

  class_addmethod(c, (method)fm4op_set,	"set", A_GIMME, 0);

	class_dspinit(c);
	class_register(CLASS_BOX, c);
	fm4op_class = c;

  fm4op_init_sine_table();
  post("sine tbl initialized");
}

void *fm4op_new(t_symbol *s, long argc, t_atom *argv){
	t_fm4op *x = (t_fm4op *)object_alloc(fm4op_class);

  // inlets: msg, frq1, amp2, fr2, amp3, frq3, ...
  x->proxy = proxy_new((t_object *)x, 7, &x->inlet_num);
  x->proxy = proxy_new((t_object *)x, 6, &x->inlet_num);
  x->proxy = proxy_new((t_object *)x, 5, &x->inlet_num);
  x->proxy = proxy_new((t_object *)x, 4, &x->inlet_num);
  x->proxy = proxy_new((t_object *)x, 3, &x->inlet_num);
  x->proxy = proxy_new((t_object *)x, 2, &x->inlet_num);
  x->proxy = proxy_new((t_object *)x, 1, &x->inlet_num);

  // sensible starting defaults
  x->base_frq = 110.0;
  for(int op = 0; op < NUM_OPS; op++){
    x->op_ratio[op] = 1.0;
    x->op_amount[op] = 0.0;
    x->op_phase[op] = 0.0;
    x->op_tune[op] = 0.0;
    x->gain = 0.5;
    x->vel_to_mod[op] = 0;
  }
  for(int env = 0; env < NUM_ENVS; env++){
    x->env_state[env] = ENV_OFF;
    x->env_out[env] = 0.0;
    // NB: times need to be non-zero for later calculations
    x->env_att[env] = 0.0001;
    x->env_dec[env] = 0.0001;
    x->env_sus[env] = 1.0;
    x->env_rel[env] = 0.0001;
    x->env_to_mod[env] = 0.0;
    x->env_to_tune[env] = 0.0;
  }
  for(int lfo = 0; lfo < NUM_ENVS; lfo++){
    x->lfo_state[lfo] = LFO_INIT;
    x->lfo_mode[lfo] = LFO_FREE;
    x->lfo_frq[lfo] = 0.001;
    x->lfo_phase[lfo] = 0;
    x->lfo_to_mod[lfo] = 0.00;
    x->lfo_to_tune[lfo] = 0;
  }
    
  if (x) {
    // MSP inlets: arg is # of singal inlets and is REQUIRED!
		dsp_setup((t_pxobject *)x, 0);	
		outlet_new(x, "signal"); 		// signal outlet (note "signal" rather than NULL)
 
	}
	return (x);
}

// NOT CALLED!, we use dsp_free for a generic free function
void fm4op_free(t_fm4op *x){
	;
}

void fm4op_assist(t_fm4op *x, void *b, long m, long a, char *s){
	if (m == ASSIST_INLET) { //inlet
		sprintf(s, "I am inlet %ld", a);
	}
	else {	// outlet
		sprintf(s, "I am outlet %ld", a);
	}
}

void fm4op_noteon(t_fm4op *x, t_symbol *s, long ac, t_atom *av){
  post("fm4op_noteon()");
  if(ac < 2){
    object_error((t_object *)x, "Error: noteon requires midi note num and vel");
    return;
  }
  x->note_num = (int) atom_getlong(av);
  int vel = (int) atom_getlong(av + 1);
  if(vel == 0){
    return fm4op_noteoff(x, gensym("noteoff"), ac, av);
  }else{
    x->vel = vel;
  }
  x->note_frq = pow(2, (x->note_num - 69) / 12.0) * 440.0;
  post("note_num: %i  frq: %.2f vel: %i", x->note_num, x->note_frq, x->vel);
  // for now just directly change the base frq, this may be different later
  x->base_frq = x->note_frq;
  x->syn_state = SYN_ON;
  // for now we are doing an instant rtz.
  for(int i=0; i < NUM_ENVS; i++){
    x->env_state[i] = ENV_INIT;
  }
  for(int i=0; i < NUM_LFOS; i++){
    if(x->lfo_mode[i] == LFO_SYNC){
      x->lfo_state[i] = LFO_INIT;
    }
  }
  // ??? DO I need to reset the ops?
  for(int op=0; op < NUM_OPS; op++){
    x->op_phase[op] = 0;
  }

}

void fm4op_noteoff(t_fm4op *x, t_symbol *s, long ac, t_atom *av){
  post("fm4op_noteoff()");
  x->syn_state = SYN_REL;
  for(int i=0; i < NUM_ENVS; i++){
    x->env_state[i] = ENV_REL;
  }
}

// translation from incoming symbols to writing internal values
void fm4op_setattr(t_fm4op *x, t_symbol *attr, double value){
  if      (attr == gensym("op1_ratio"))   x->op_ratio[0] = value;
  else if (attr == gensym("op2_ratio"))   x->op_ratio[1] = value;
  else if (attr == gensym("op3_ratio"))   x->op_ratio[2] = value;
  else if (attr == gensym("op4_ratio"))   x->op_ratio[3] = value;
  else if (attr == gensym("op1_amount"))  x->op_amount[0] = value;
  else if (attr == gensym("op2_amount"))  x->op_amount[1] = value;
  else if (attr == gensym("op3_amount"))  x->op_amount[2] = value;
  else if (attr == gensym("op4_amount"))  x->op_amount[3] = value;
  else if (attr == gensym("op1_tune"))    x->op_tune[0] = value;
  else if (attr == gensym("op2_tune"))    x->op_tune[1] = value;
  else if (attr == gensym("op3_tune"))    x->op_tune[2] = value;
  else if (attr == gensym("op4_tune"))    x->op_tune[3] = value;
  else if (attr == gensym("lfo1_ms"))    x->lfo_frq[0] = (value >= 1 ? (1.0 / (value / 1000)) : 1.0);  // avoid divide by 0 errors
  else if (attr == gensym("lfo2_ms"))    x->lfo_frq[1] = (value >= 1 ? (1.0 / (value / 1000)) : 1.0);  
  else if (attr == gensym("lfo3_ms"))    x->lfo_frq[2] = (value >= 1 ? (1.0 / (value / 1000)) : 1.0);  
  else if (attr == gensym("lfo4_ms"))    x->lfo_frq[3] = (value >= 1 ? (1.0 / (value / 1000)) : 1.0);  

  // env 1
  // on env changes we also recalculate the incr amounts
  else if (attr == gensym("env1_att")){
    x->env_att[0] = (value >= 0.0001 ? value : 0.0001);
    x->env_att_inc[0] = (1.0 / x->env_att[0]) / sr; 
  }
  else if (attr == gensym("env1_dec")){
    x->env_dec[0] = (value >= 0.0001 ? value : 0.0001);
    x->env_dec_inc[0] = ((1.0 - x->env_sus[0]) / x->env_dec[0]) / sr * -1; 
  }
  else if (attr == gensym("env1_sus")){
    x->env_sus[0] = (value <= 1.0 ? (value >= 0 ? value : 0) : 1.0);  // clamp between 0-1
  }
  else if (attr == gensym("env1_rel")){
    x->env_rel[0] = (value >= 0.0001 ? value : 0.0001);
    x->env_rel_inc[0] = (x->env_sus[0] / x->env_rel[0]) / sr * -1; 
  }
  // env 2
  else if (attr == gensym("env2_att")){
    x->env_att[1] = (value >= 0.0001 ? value : 0.0001);
    x->env_att_inc[1] = (1.0 / x->env_att[1]) / sr; 
  }
  else if (attr == gensym("env2_dec")){
    x->env_dec[1] = (value >= 0.0001 ? value : 0.0001);
    x->env_dec_inc[1] = ((1.0 - x->env_sus[1]) / x->env_dec[1]) / sr * -1; 
  }
  else if (attr == gensym("env2_sus")){
    x->env_sus[1] = (value <= 1.0 ? (value >= 0 ? value : 0) : 1.0);  // clamp between 0-1
  }
  else if (attr == gensym("env2_rel")){
    x->env_rel[1] = (value >= 0.0001 ? value : 0.0001);
    x->env_rel_inc[1] = (x->env_sus[1] / x->env_rel[1]) / sr * -1; 
  }
  // env 3
  else if (attr == gensym("env3_att")){
    x->env_att[2] = (value >= 0.0001 ? value : 0.0001);
    x->env_att_inc[2] = (1.0 / x->env_att[2]) / sr; 
  }
  else if (attr == gensym("env3_dec")){
    x->env_dec[2] = (value >= 0.0001 ? value : 0.0001);
    x->env_dec_inc[2] = ((1.0 - x->env_sus[2]) / x->env_dec[2]) / sr * -1; 
  }
  else if (attr == gensym("env3_sus")){
    x->env_sus[2] = (value <= 1.0 ? (value >= 0 ? value : 0) : 1.0);  // clamp between 0-1
  }
  else if (attr == gensym("env3_rel")){
    x->env_rel[2] = (value >= 0.0001 ? value : 0.0001);
    x->env_rel_inc[2] = (x->env_sus[2] / x->env_rel[2]) / sr * -1; 
  }
  // env 4
  else if (attr == gensym("env4_att")){
    x->env_att[3] = (value >= 0.0001 ? value : 0.0001);
    x->env_att_inc[3] = (1.0 / x->env_att[3]) / sr; 
  }
  else if (attr == gensym("env4_dec")){
    x->env_dec[3] = (value >= 0.0001 ? value : 0.0001);
    x->env_dec_inc[3] = ((1.0 - x->env_sus[3]) / x->env_dec[3]) / sr * -1; 
  }
  else if (attr == gensym("env4_sus")){
    x->env_sus[3] = (value <= 1.0 ? (value >= 0 ? value : 0) : 1.0);  // clamp between 0-1
  }
  else if (attr == gensym("env4_rel")){
    x->env_rel[3] = (value >= 0.0001 ? value : 0.0001);
    x->env_rel_inc[3] = (x->env_sus[3] / x->env_rel[3]) / sr * -1; 
  }
 
  else if (attr == gensym("lfo1_to_tune"))   x->lfo_to_tune[0] = value;
  else if (attr == gensym("lfo2_to_tune"))   x->lfo_to_tune[1] = value;
  else if (attr == gensym("lfo3_to_tune"))   x->lfo_to_tune[2] = value;
  else if (attr == gensym("lfo4_to_tune"))   x->lfo_to_tune[3] = value;
  else if (attr == gensym("lfo1_to_mod"))    x->lfo_to_mod[0] = value;
  else if (attr == gensym("lfo2_to_mod"))    x->lfo_to_mod[1] = value;
  else if (attr == gensym("lfo3_to_mod"))    x->lfo_to_mod[2] = value;
  else if (attr == gensym("lfo4_to_mod"))    x->lfo_to_mod[3] = value;
  else if (attr == gensym("env1_to_mod"))    x->env_to_mod[0] = value;  // doesn't actually do anything yet
  else if (attr == gensym("env2_to_mod"))    x->env_to_mod[1] = value;
  else if (attr == gensym("env3_to_mod"))    x->env_to_mod[2] = value;  // doesn't actually do anything yet
  else if (attr == gensym("env4_to_mod"))    x->env_to_mod[3] = value;
  else if (attr == gensym("env1_to_tune"))   x->env_to_tune[0] = value;
  else if (attr == gensym("env2_to_tune"))   x->env_to_tune[1] = value;
  else if (attr == gensym("env3_to_tune"))   x->env_to_tune[2] = value;
  else if (attr == gensym("env4_to_tune"))   x->env_to_tune[3] = value;
  else
      post("setting %s not implemented", attr->s_name);
}

void fm4op_set(t_fm4op *x, t_symbol *s, long ac, t_atom *av){
  if(ac != 2){
    object_error((t_object *)x, "Error: set takes one symbol and one float");
    return;
  }
  t_symbol *attr = atom_getsym(av);
  double value = atom_getfloat(av + 1);
  post("set %s %.2f", attr->s_name, value);
  fm4op_setattr(x, attr, value);
}

/*
void fm4op_float(t_fm4op *x, double f){
  long inlet = proxy_getinlet((t_object *)x);
  //post("float msg, inlet: %i", inlet);
  switch(inlet){
    case 0:
        post("base frq: %.2f", f);
        x->base_frq = f;
        break;
    case 1:
        post("carrier ratio: %.2f", f);
        x->op_ratio[0] = f;
        break;
    case 2:
        post("carrier tune: %.2f", f);
        x->op_tune[0] = f;
        break;
    case 3:
        post("op2 ratio: %.2f", f);
        x->op_ratio[1] = f;
        break;
    case 4:
        post("op2 tune: %.2f", f);
        x->op_tune[1] = f;
        break;
    case 5:
        post("op2 mod index to %.4f", f);
        x->op_amount[1] = f / (M_PI * 2);
        post("- op2 amt in 0-1 phase now %.2f", x->op_amount[1]);
        break;
    }
}

void fm4op_int(t_fm4op *x, long n) {
  long inlet = proxy_getinlet((t_object *)x);
  post("int msg, inlet: %i", inlet);
	fm4op_float(x, (double)n);
}
*/


// registers a function for the signal chain in Max
void fm4op_dsp64(t_fm4op *x, t_object *dsp64, short *count, double samplerate, long maxvectorsize, long flags){
	post("fm4op_dsp64() sample rate is: %f", samplerate);
  sr = samplerate;
  object_method(dsp64, gensym("dsp_add64"), x, fm4op_perform64, 0, NULL);

  // set our initial env incrs now that sample rate has been set
  for(int env = 0; env < NUM_ENVS; env++){
    x->env_att_inc[env] = (1.0 / x->env_att[env]) / sr; 
    x->env_dec_inc[env] = ((1.0 - x->env_sus[env]) / x->env_dec[env]) / sr * -1; 
    x->env_rel_inc[env] = (x->env_sus[env] / x->env_dec[env]) / sr * -1; 
  }
  // set initial lfo increments
  for(int lfo = 0; lfo < NUM_ENVS; lfo++){
    x->lfo_phase_inc[lfo] = x->lfo_frq[lfo] / sr; 
  }
  for(int op = 0; op < NUM_OPS; op++){
    x->op_phase[op] = 0.0;
  }

}

// increment a 0 to 1 phase with wrapping
double fm4op_incr_phase(double phase, double phase_incr){
    phase += phase_incr;
    // because phase could go backwards we could need to wrap in either direction
    if( phase > 1.0 ){
      while(phase > 1.0) phase -= 1.0;
    }
    else if( phase < 0.0 ){
      while(phase < 0.0) phase += 1.0;
    }
    return phase;
}

// render an operator's sine wave, using the ops ratio and the base freq 
double fm4op_render_op(t_fm4op *x, int op){
    // convert tune to ratio from cents
    double tune_final = x->op_tune_final[op];
    double op_phase = x->op_phase[op];
    double tune_ratio = pow(2, (x->op_tune_final[op] / 1200)); 
    // increment the phasor for the next pass
    //double phase_incr = (x->base_frq * x->op_ratio[op] * tune_ratio ) / sr; 
    double phase_incr = (x->note_frq * x->op_ratio[op] ) / sr; 
    x->op_phase[op] = fm4op_incr_phase(x->op_phase[op], phase_incr);
    // for debugger to look at
    double phase = x->op_phase[op];
    int sine_table_index = (int) (OSC_TABLE_SIZE * x->op_phase[ op ]);
    double out_sample = sine_table[sine_table_index];
    return out_sample;
}

// render an envelope
double fm4op_render_env(t_fm4op *x, int env){
    // short circuit if no note playing
    //if(x->env_state[env] == ENV_OFF){
    //  return;
    //}

    // FSM for envelopes
    switch( x->env_state[env] ){
      case ENV_INIT:
        //post("env initing");
        //post("att incr amount: %.2f", x->env_att_inc[env] );
        x->env_out[env] = 0.0;
        x->env_state[env] = ENV_ATT;
        break;
      case ENV_ATT:
        //post("attack, incr amount: %.2f", x->env_att_inc[env] );
        x->env_out[env] += x->env_att_inc[env]; 
        if(x->env_out[env] >= 1.0){
          x->env_out[env] = 1.0;
          x->env_state[env] = ENV_DEC;
        }
        break;
      case ENV_DEC:
        x->env_out[env] += x->env_dec_inc[env]; 
        if(x->env_out[env] <= x->env_sus[env]){
          x->env_out[env] = x->env_sus[env];
          x->env_state[env] = ENV_SUS;
        }
        break;
      case ENV_SUS:
        // no op
        break;
      case ENV_REL:
        //post("release, incr amount: %.2f", x->env_rel_inc[env] );
        x->env_out[env] += x->env_rel_inc[env]; 
        if(x->env_out[env] <= 0.0){
          x->env_out[env] = 0.0;
          x->env_state[env] = ENV_OFF;
        }
        break;
      case ENV_OFF:
        break;
    }
}

// render an lfo, returning the outsample for it
double fm4op_render_lfo(t_fm4op *x, int lfo){
    // FSM for LFOS
    long table_index;
    double lfo_frq, lfo_phase_incr, lfo_phase, lfo_out;

    switch( x->lfo_state[lfo] ){
      case LFO_INIT:
        //post("lfo init");
        x->lfo_phase[ lfo ] = 0;
        x->lfo_state[ lfo ] = LFO_ON;
        x->lfo_out[ lfo ] = 0;
        break;
      case LFO_ON:
        // increment the phase
        lfo_frq = x->lfo_frq[lfo];
        lfo_phase_incr = lfo_frq / sr; 
        lfo_phase = fm4op_incr_phase(x->lfo_phase[lfo], lfo_phase_incr);
        table_index = (long) (OSC_TABLE_SIZE * lfo_phase);
        lfo_out = sine_table[ table_index ];
        // write the output and resulting phase for the next pass
        x->lfo_out[lfo] = lfo_out;
        x->lfo_phase[lfo] = lfo_phase;
        break;
    }
}

// render the modulation matrix
// very simple version right now, envs and lfos can only modulate one dest
double fm4op_render_mod_matrix(t_fm4op *x){
  for(int op=0; op < NUM_OPS; op++){
    x->op_amount_final[op] = x->op_amount[op];    
    x->op_tune_final[op] = x->op_tune[op];      
    x->op_amount_final[op] += (x->env_to_mod[op] * x->env_out[op]);
    // make the lfo to mod amount unipolar before applying it
    x->op_amount_final[op] += x->lfo_to_mod[op] * ((x->lfo_out[op] + 1.0) / 2);
    // tune lfo stays bipolar
    x->op_tune_final[op] += x->lfo_to_tune[op] * x->lfo_out[op];
    x->op_tune_final[op] += x->env_to_tune[op] * x->env_out[op];
  }
  //post("op amount: %.5f", x->op_amount_final[1]);
  //post("op tune: %.5f", x->op_tune_final[1]);

}

// TODO allow velocity curves, for now it's just dumb linear
double fm4op_vel_to_amp(t_fm4op *x, int vel){
  return 1.0 / 127.0 * vel;
}

// this is the 64-bit perform method audio vectors
void fm4op_perform64(t_fm4op *x, t_object *dsp64, double **ins, long numins, double **outs, long numouts, long sampleframes, long flags, void *userparam)
{
	//t_double *inL = ins[0];		// we get audio for each inlet of the object from the **ins argument
	t_double *outL = outs[0];	// we get audio for each outlet of the object from the **outs argument
  double out_sample;

  for(int s = 0; s < sampleframes; s++){
    // render envs, writes val to x->env_out[e]
    for(int e = 0; e < NUM_ENVS; e++){
      fm4op_render_env(x, e);  
    }
    // render lfos, writes to x->lfo_out
    for(int lfo = 0; lfo < NUM_ENVS; lfo++){
      fm4op_render_lfo(x, lfo);  
    }
    fm4op_render_mod_matrix(x);
  
    // algorithm branching should go here
    // op3->op2->op1

    // OP3
    // get op3's sine output
    double op3_out = fm4op_render_op(x, 2);
    // multiply it by op3's mod amount, which is the incoming mod index / 2PI
    // this gives us the value we add to op2's phase
    double op3_phase_incr = op3_out * x->op_amount_final[2];
    // add to phase value for op2
    x->op_phase[1] = fm4op_incr_phase(x->op_phase[1], op3_phase_incr);
    
    // get op2's sine output (will be PM'd by the above)
    double op2_out = fm4op_render_op(x, 1);
    // multiply it by op2's mod amount, which is the incoming mod index / 2PI
    // this gives us the value we add to op1's phase
    double op2_phase_incr = op2_out * x->op_amount_final[1];
    // add to phase value for op1
    x->op_phase[0] = fm4op_incr_phase(x->op_phase[0], op2_phase_incr);
    
    // now render op1 (carrier) to get sound
    out_sample = fm4op_render_op(x, 0);
   
    // env 1 always mods amplitude
    double vel_amp = fm4op_vel_to_amp(x, x->vel);
    *outL++ = out_sample * ( x->gain * x->env_out[0] * vel_amp );

  }

}


