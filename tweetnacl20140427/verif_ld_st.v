Require Import floyd.proofauto.
Local Open Scope logic.
Require Import List. Import ListNotations.
Require Import sha.general_lemmas.

Require Import tweetnacl20140427.split_array_lemmas.
Require Import ZArith. 
Require Import tweetnacl20140427.tweetNaclBase.
Require Import tweetnacl20140427.Salsa20.
Require Import tweetnacl20140427.tweetnaclVerifiableC.
Require Import tweetnacl20140427.verif_salsa_base.

Require Import tweetnacl20140427.spec_salsa.

Opaque Snuffle20. Opaque Snuffle.Snuffle. Opaque prepare_data. 
Opaque fcore_result.

(*VST Issue: why do these two specs have to be made Opaque?
 If we delete the line, the "forward" for statement aux = x[0] in 
 the verifacation of ld32 gets stuck.*)
Opaque crypto_core_salsa20_spec. Opaque crypto_core_hsalsa20_spec.

Lemma L32_spec_ok: semax_body SalsaVarSpecs SalsaFunSpecs
       f_L32 L32_spec.
Proof.
start_function.
Time forward. (*8.8*)
Time entailer!. (*0.8*)
assert (W: Int.zwordsize = 32). reflexivity.
assert (U: Int.unsigned Int.iwordsize=32). reflexivity. simpl.
remember (Int.ltu c Int.iwordsize) as d. symmetry in Heqd.
destruct d; simpl. 
{ clear Heqd.
  remember (Int.ltu (Int.sub (Int.repr 32) c) Int.iwordsize) as z. symmetry in Heqz.
  destruct z.
  - simpl; split; trivial. split. 2: split; trivial.
    apply ltu_inv in Heqz. unfold Int.sub in *.
    rewrite (Int.unsigned_repr 32) in *; try (rewrite int_max_unsigned_eq; omega).
    rewrite Int.unsigned_repr in Heqz. 2: rewrite int_max_unsigned_eq; omega.
    unfold Int.rol, Int.shl, Int.shru. rewrite or_repr. 
    rewrite Z.mod_small, W; simpl; try omega.
    rewrite Int.unsigned_repr. 2: rewrite int_max_unsigned_eq; omega.
    rewrite Int.and_mone. trivial.
  - apply ltu_false_inv in Heqz. rewrite U in *. 
    unfold Int.sub in Heqz. 
    rewrite (Int.unsigned_repr 32), Int.unsigned_repr in Heqz. omega.
    rewrite int_max_unsigned_eq; omega.
    rewrite int_max_unsigned_eq; omega. }
{ apply ltu_false_inv in Heqd. rewrite U in *. omega. }
Time Qed. (*0.9*)

Lemma ld32_spec_ok: semax_body SalsaVarSpecs SalsaFunSpecs
       f_ld32 ld32_spec.
Proof.
start_function.
destruct B as (((b0, b1), b2), b3). simpl.
specialize Byte_max_unsigned_Int_max_unsigned; intros BND.
assert (RNG3:= Byte.unsigned_range_2 b3).
assert (RNG2:= Byte.unsigned_range_2 b2).
assert (RNG1:= Byte.unsigned_range_2 b1).
assert (RNG0:= Byte.unsigned_range_2 b0).
Time forward. (*1.8*)
Time entailer!; omega. (*1.1*)
Time forward. (*2*)
Time entailer!; omega. (*1.1*)
Time forward. (*1.1*)
Time forward. (*2.2*)
Time entailer!; omega. (*1.3*)
Time forward. (*1.5*)
drop_LOCAL 1%nat. 
Time forward.
Time entailer!; omega. (*1.3*)
Time forward. (*5.2*)
Time entailer!.
  assert (WS: Int.zwordsize = 32). reflexivity.
  assert (TP: two_p 8 = Byte.max_unsigned + 1). reflexivity.
  assert (BMU: Byte.max_unsigned = 255). reflexivity. simpl.
  repeat rewrite Int.shifted_or_is_add; try repeat rewrite Int.unsigned_repr; try omega.
  f_equal. f_equal. simpl. 
    rewrite Z.mul_add_distr_r. 
    rewrite (Zmult_comm (Z.pow_pos 2 8)).
    rewrite (Zmult_comm (Z.pow_pos 2 16)).
    rewrite (Zmult_comm (Z.pow_pos 2 24)). 
    simpl. repeat rewrite <- two_power_pos_correct.
    rewrite Z.mul_add_distr_r.
    rewrite Z.mul_add_distr_r.
    repeat rewrite <- Z.mul_assoc. 
    rewrite <- Z.add_assoc. rewrite <- Z.add_assoc. rewrite Z.add_comm. f_equal.
    rewrite Z.add_comm. f_equal. rewrite Z.add_comm. f_equal.
  rewrite TP, BMU, Z.mul_add_distr_l, int_max_unsigned_eq. omega. 
  rewrite TP, BMU, Z.mul_add_distr_l, int_max_unsigned_eq. omega.
  rewrite TP, BMU, Z.mul_add_distr_l, int_max_unsigned_eq. omega.
Time Qed. (*6.7*)

Lemma ST32_spec_ok: semax_body SalsaVarSpecs SalsaFunSpecs
       f_st32 st32_spec.
Proof. 
start_function.
Intros l. rename H into Hl.
remember (littleendian_invert u) as U. destruct U as [[[u0 u1] u2] u3].

Time forward_for_simple_bound 4 (EX i:Z, 
  (PROP  ()
   LOCAL (temp _x x; temp _u (Vint (iterShr8 u (Z.to_nat i))))
   SEP (data_at Tsh (Tarray tuchar 4 noattr) 
              (sublist 0 i (map Vint (map Int.repr (map Byte.unsigned ([u0;u1;u2;u3])))) ++ 
               sublist i (Zlength l) l)
                x))).
(*0.9*)
{ Time entailer!. (*1*) rewrite sublist_same; trivial. }
{ rename H into I.
  Time assert_PROP (field_compatible (Tarray tuchar 4 noattr) [] x /\ isptr x) 
       as FC_ptrX by solve [entailer!]. (*2.3*)
  destruct FC_ptrX as [FC ptrX].
  Time forward. (*3.2*)
  Time forward. (*0.8*)  
  rewrite Z.add_comm, Z2Nat.inj_add; try omega.
  Time entailer!. (*1.5*)
  unfold upd_Znth.
  autorewrite with sublist. 
  rewrite field_at_data_at. simpl. unfold field_address. simpl.
  if_tac. 2: solve [contradiction].
  rewrite isptr_offset_val_zero; trivial. clear H.
  rewrite Zlength_length in Hl. 2: omega. 
  destruct l; simpl in Hl. omega.
        destruct l; simpl in Hl. omega.
        destruct l; simpl in Hl. omega.
        destruct l; simpl in Hl. omega.
        destruct l; simpl in Hl. 2: solve [omega]. clear Hl.
  apply data_at_ext.
        assert (ZW: Int.zwordsize = 32) by reflexivity.
        assert (EIGHT: Int.unsigned (Int.repr 8) = 8). apply Int.unsigned_repr. rewrite int_max_unsigned_eq; omega.
        inv HeqU. clear - ZW EIGHT I.
        destruct (zeq i 0); subst; simpl. f_equal. f_equal.
        { rewrite Byte.unsigned_repr.              
            rewrite (Fcore_Zaux.Zmod_mod_mult _ (2^8) (2^8)). 2: cbv; trivial. 2: cbv; intros; discriminate.
            rewrite (Fcore_Zaux.Zmod_mod_mult _ (2^16) (2^8)). 2: cbv; trivial. 2: cbv; intros; discriminate.
            rewrite <- (Int.zero_ext_mod 8).
              rewrite Int.repr_unsigned; trivial.
              rewrite ZW; omega.
          assert (0 <= ((Int.unsigned u mod Z.pow_pos 2 24) mod Z.pow_pos 2 16) mod Z.pow_pos 2 8 < Byte.modulus).
            apply Z_mod_lt. cbv; trivial. 
            unfold Byte.max_unsigned. omega. }
        destruct (zeq i 1); subst; simpl. f_equal. f_equal. f_equal.
        { rewrite Byte.unsigned_repr.  
          Focus 2. assert (0 <= (Int.unsigned u mod Z.pow_pos 2 24) mod Z.pow_pos 2 16 / Z.pow_pos 2 8 < Byte.modulus).
                   Focus 2. unfold Byte.max_unsigned. omega.
                   split. apply Z_div_pos. cbv; trivial. apply Z_mod_lt. cbv; trivial.
                   apply Zdiv_lt_upper_bound. cbv; trivial. apply Z_mod_lt. cbv; trivial.
          apply Int.same_bits_eq. rewrite ZW; intros.
          rewrite Int.bits_zero_ext, Int.testbit_repr; try apply H. 
          rewrite (Z.div_pow2_bits _ 8); try omega.
          rewrite (Int.Ztestbit_mod_two_p 16); try omega.
          rewrite (Int.Ztestbit_mod_two_p 24); try omega.
          rewrite Int.bits_shru; try omega. rewrite EIGHT, ZW, Ztest_Inttest.
          remember (zlt i 8). 
          destruct s. repeat rewrite zlt_true. trivial. omega. omega. omega.
          rewrite zlt_false. trivial. omega. }
        destruct (zeq i 2); subst; simpl. f_equal. f_equal. f_equal.
          f_equal.
        { rewrite Byte.unsigned_repr.  
          Focus 2. assert (0 <= Int.unsigned u mod Z.pow_pos 2 24 / Z.pow_pos 2 16 < Byte.modulus).
                   2: unfold Byte.max_unsigned; omega.
                   split. apply Z_div_pos. cbv; trivial. apply Z_mod_lt. cbv; trivial.
                   apply Zdiv_lt_upper_bound. cbv; trivial. apply Z_mod_lt. cbv; trivial.
          apply Int.same_bits_eq. rewrite ZW; intros.
          rewrite Int.bits_zero_ext, Int.testbit_repr; try apply H. 
          rewrite Int.bits_shru; try omega. rewrite EIGHT, ZW.
          rewrite (Z.div_pow2_bits _ 16); try omega.
          rewrite (Int.Ztestbit_mod_two_p 24); try omega.
          rewrite Ztest_Inttest.
          remember (zlt i 8). 
          destruct s. repeat rewrite zlt_true. rewrite Int.bits_shru, EIGHT, ZW.
              rewrite zlt_true. rewrite <- Z.add_assoc. reflexivity. omega. omega. omega. omega.
          rewrite zlt_false. trivial. omega. }
        destruct (zeq i 3); subst; simpl. f_equal. f_equal. f_equal. f_equal.
          f_equal.
        { rewrite Byte.unsigned_repr.  
          Focus 2. assert (0 <= Int.unsigned u / Z.pow_pos 2 24 < Byte.modulus).
                   2: unfold Byte.max_unsigned; omega.
                   split. apply Z_div_pos. cbv; trivial. apply Int.unsigned_range. 
                   apply Zdiv_lt_upper_bound. cbv; trivial. apply Int.unsigned_range. 
          apply Int.same_bits_eq. rewrite ZW; intros.
          rewrite Int.bits_zero_ext, Int.testbit_repr; try apply H. 
          rewrite Int.bits_shru; try omega. rewrite EIGHT, ZW.
          rewrite (Z.div_pow2_bits _ 24); try omega.
          rewrite Ztest_Inttest.
          remember (zlt i 8). 
          destruct s. rewrite zlt_true. rewrite Int.bits_shru, EIGHT, ZW.
              rewrite zlt_true. rewrite Int.bits_shru, EIGHT, ZW. 
              rewrite zlt_true. repeat rewrite <- Z.add_assoc. reflexivity. omega. omega. omega. omega. omega.
          rewrite Int.bits_above. trivial. omega. }
        omega. }
  rewrite Hl.
  Time forward. (*1.6*)
Time Qed. (*4.9*) (*FIXME NOW: 11secs*)

(*
Definition L32_specZ :=
  DECLARE _L32
   WITH x : int, c: int
   PRE [ _x OF tuint, _c OF tint ]
      PROP () (*c=Int.zero doesn't seem to satisfy spec???*)
      LOCAL (temp _x (Vint x); temp _c (Vint Int.zero))
      SEP ()
  POST [ tuint ] 
     PROP (True)
     LOCAL ()
     SEP ().

Definition LDZFunSpecs : funspecs := 
  L32_specZ::nil.

Lemma L32_specZ_ok: semax_body SalsaVarSpecs LDZFunSpecs
       f_L32 L32_specZ.
Proof.
start_function.
name x' _x.
name c' _c.
forward. entailer. apply prop_right.
assert (W: Int.zwordsize = 32). reflexivity.
assert (U: Int.unsigned Int.iwordsize=32). reflexivity.
(*remember (Int.eq c' Int.zero) as z.
  destruct z. apply binop_lemmas.int_eq_true in Heqz. subst. simpl. *)
remember (Int.ltu (Int.repr 32) Int.iwordsize) as d. symmetry in Heqd.
destruct d; simpl. 
Focus 2. apply ltu_false_inv in Heqd. rewrite U in *. rewrite Int.unsigned_repr in Heqd. 2: rewrite int_max_unsigned_eq; omega.
clear Heqd. split; trivial.
remember (Int.ltu (Int.sub (Int.repr 32) c') Int.iwordsize) as z. symmetry in Heqz.
destruct z.
Focus 2. apply ltu_false_inv in Heqz. rewrite U in *. 
         unfold Int.sub in Heqz. 
         rewrite (Int.unsigned_repr 32) in Heqz. 
           rewrite Int.unsigned_repr in Heqz. omega. rewrite int_max_unsigned_eq; omega.
           rewrite int_max_unsigned_eq; omega.
simpl; split; trivial. split; trivial.
apply ltu_inv in Heqz. unfold Int.sub in *.
  rewrite (Int.unsigned_repr 32) in *; try (rewrite int_max_unsigned_eq; omega).
  rewrite Int.unsigned_repr in Heqz. 2: rewrite int_max_unsigned_eq; omega.
  unfold Int.rol, Int.shl, Int.shru. rewrite or_repr. 
  assert (Int.unsigned c' mod Int.zwordsize = Int.unsigned c').
    apply Zmod_small. rewrite W; omega.
  rewrite H0, W. f_equal. f_equal. f_equal.
  rewrite Int.unsigned_repr. 2: rewrite int_max_unsigned_eq; omega.
  rewrite Int.and_mone. trivial.
Qed.
*)
