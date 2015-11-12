Require Import floyd.proofauto.
Require Import sha.SHA256.
Require Import sha.spec_sha.
Require Import sha.sha.
Require Export sha.pure_lemmas.
Require Export general_lemmas.
Export ListNotations.

Local Open Scope logic.

Global Opaque K256.

Transparent peq.

Lemma mapsto_tc_val:
  forall sh t p v,
  readable_share sh ->
  v <> Vundef ->
  mapsto sh t p v = !! tc_val t v && mapsto sh t p v .
Proof.
intros.
apply pred_ext.
apply andp_right; auto.
unfold mapsto; simpl.
destruct (access_mode t); try apply FF_left.
destruct (type_is_volatile t); try apply FF_left.
destruct p; try apply FF_left.
if_tac; try contradiction. apply orp_left.
normalize.
normalize.
congruence.
normalize.
Qed.

(*
Lemma elim_globals_only'':
  forall i t rho,  
   (exists Delta, tc_environ Delta rho /\
       (var_types Delta) ! i = None /\ isSome ((glob_types Delta) ! i)) ->
       (eval_var i t (globals_only rho)) = eval_var i t rho.
Proof. 
  intros.
  unfold_lift.
 destruct H as [Delta [?[? ?]]].
  destruct ((glob_types Delta) ! i) eqn:?; try contradiction.
  erewrite elim_globals_only; eauto.
Qed.

Hint Rewrite elim_globals_only'' using (eexists; split3; [eassumption | reflexivity | apply I]) : norm.

Lemma elim_make_args:
  forall i t il vl rho,  
   (exists Delta, tc_environ Delta rho /\
       (var_types Delta) ! i = None /\ isSome ((glob_types Delta) ! i)) ->
       (eval_var i t (make_args il vl rho)) = eval_var i t rho.
Proof. 
  intros.
 revert vl; induction il; destruct vl; simpl; auto.
 apply elim_globals_only''; auto. 
 rewrite <- (IHil vl).
 clear.
 reflexivity.
Qed.

Hint Rewrite elim_make_args using (eexists; split3; [eassumption | reflexivity | apply I]) : norm.
*)

Fixpoint loops (s: statement) : list statement :=
 match s with 
  | Ssequence a b => loops a ++ loops b
  | Sloop _ _ => [s]
  | Sifthenelse _ a b => loops a ++ loops b
  | _ => nil
  end.

Lemma nth_big_endian_integer:
  forall i bl w, 
   nth_error bl i = Some w ->
    w = big_endian_integer 
                   (sublist (Z.of_nat i * WORD)
                        (Z.succ (Z.of_nat i) * WORD)
                   (map Int.repr (intlist_to_Zlist bl))).
Proof.
induction i; destruct bl; intros; inv H.
*
 unfold sublist; simpl.
 rewrite big_endian_integer4.
 repeat rewrite Int.repr_unsigned.
 assert (Int.zwordsize=32)%Z by reflexivity.
 unfold Z_to_Int, Shr; simpl.
 change 255%Z with (Z.ones 8).
 apply Int.same_bits_eq; intros;
 autorewrite with testbit.
 if_tac; simpl.
 if_tac; simpl.
 if_tac; simpl; autorewrite with testbit. auto. f_equal; omega.
 rewrite if_false by omega. autorewrite with testbit. f_equal; omega.
 rewrite if_false by omega. rewrite if_false by omega.
 autorewrite with testbit. f_equal; omega.
*
specialize (IHi _ _ H1); clear H1.
simpl map.
rewrite IHi.
unfold sublist.
replace (Z.to_nat (Z.of_nat (S i) * WORD)) with (4 + Z.to_nat (Z.of_nat i * WORD))%nat
  by (rewrite plus_comm, inj_S; unfold Z.succ; rewrite Z.mul_add_distr_r;
        rewrite Z2Nat.inj_add by (change WORD with 4; omega); reflexivity).
rewrite <- skipn_skipn.
simpl skipn.
f_equal. f_equal. f_equal. rewrite inj_S.  unfold Z.succ. 
rewrite !Z.mul_add_distr_r; omega.
Qed.

Lemma Znth_big_endian_integer:
  forall i bl, 
   0 <= i < Zlength bl ->
   Znth i bl Int.zero =
     big_endian_integer 
                   (sublist (i * WORD) (Z.succ i * WORD)
                   (map Int.repr (intlist_to_Zlist bl))).
Proof.
intros.
unfold Znth.
 rewrite if_false by omega.
pose proof (nth_error_nth _ Int.zero (Z.to_nat i) bl).
rewrite <- (Z2Nat.id i) at 2 3 by omega.
apply nth_big_endian_integer.
apply H0.
apply Nat2Z.inj_lt.
rewrite Z2Nat.id by omega.
rewrite <- Zlength_correct; omega.
Qed.

Fixpoint sequence (cs: list statement) s :=
 match cs with
 | nil => s
 | c::cs' => Ssequence c (sequence cs' s)
 end.

Fixpoint rsequence (cs: list statement) s :=
 match cs with
 | nil => s
 | c::cs' => Ssequence (rsequence cs' s) c
 end.

Lemma sequence_rsequence:
 forall Espec CS Delta P cs s0 s R, 
    @semax CS Espec Delta P (Ssequence s0 (sequence cs s)) R  <->
  @semax CS Espec Delta P (Ssequence (rsequence (rev cs) s0) s) R.
Proof.
intros.
revert Delta P R s0 s; induction cs; intros.
simpl. apply iff_refl.
simpl.
rewrite seq_assoc.
rewrite IHcs; clear IHcs.
replace (rsequence (rev cs ++ [a]) s0) with
    (rsequence (rev cs) (Ssequence s0 a)); [apply iff_refl | ].
revert s0 a; induction (rev cs); simpl; intros; auto.
rewrite IHl. auto.
Qed.

Lemma seq_assocN:  
  forall {Espec: OracleKind} CS, 
   forall Q Delta P cs s R,
        @semax CS Espec Delta P (sequence cs Sskip) (normal_ret_assert Q) ->
         @semax CS Espec 
       (update_tycon Delta (sequence cs Sskip)) Q s R ->
        @semax CS Espec Delta P (sequence cs s) R.
Proof.
intros.
rewrite semax_skip_seq.
rewrite sequence_rsequence.
rewrite semax_skip_seq in H.
rewrite sequence_rsequence in H.
rewrite <- semax_seq_skip in H.
eapply semax_seq'; [apply H | ].
eapply semax_extensionality_Delta; try apply H0.
clear.
revert Delta; induction cs; simpl; intros.
apply tycontext_sub_refl.
eapply tycontext_sub_trans; [apply IHcs | ].
clear.
revert Delta; induction (rev cs); simpl; intros.
apply tycontext_sub_refl.
apply update_tycon_sub.
apply IHl.
Qed.

Fixpoint sequenceN (n: nat) (s: statement) : list statement :=
 match n, s with 
 | S n', Ssequence a s' => a::sequenceN n' s'
 | _, _ => nil
 end.

Lemma data_block_local_facts:
 forall {cs: compspecs} sh f data,
  data_block sh f data |-- 
   prop (field_compatible (tarray tuchar (Zlength f)) [] data
           /\ Forall isbyteZ f).
Proof.
intros. unfold data_block, array_at.
simpl.
entailer.
Qed.
Hint Resolve @data_block_local_facts : saturate_local.

Require Import JMeq.

Lemma reptype_tarray {cs: compspecs}:
   forall t len, reptype (tarray t len) = list (reptype t).
Proof.
intros.
rewrite reptype_ind. simpl. reflexivity.
Qed.

(*
Lemma firstn_map {A B} (f:A -> B): forall n l, 
      firstn n (map f l) = map f (firstn n l).
Proof. intros n.
induction n; simpl; intros. trivial.
  destruct l; simpl. trivial.
  rewrite IHn. trivial.
Qed.

Lemma skipn_map {A B} (f:A -> B): forall n l, 
      skipn n (map f l) = map f (skipn n l).
Proof. intros n.
induction n; simpl; intros. trivial.
  destruct l; simpl. trivial.
  rewrite IHn. trivial.
Qed.
*)

Local Open Scope nat.

(*** Application of Omega stuff ***)

Lemma CBLOCKz_eq : CBLOCKz = 64%Z.
Proof. reflexivity. Qed.
Lemma LBLOCKz_eq : LBLOCKz = 16%Z.
Proof. reflexivity. Qed.

Ltac helper2 := 
 match goal with
   | |- context [CBLOCK] => add_nonredundant (CBLOCK_eq)
   | |- context [LBLOCK] => add_nonredundant (LBLOCK_eq)
   | |- context [CBLOCKz] => add_nonredundant (CBLOCKz_eq)
   | |- context [LBLOCKz] => add_nonredundant (LBLOCKz_eq)
   | H: context [CBLOCK] |- _ => add_nonredundant (CBLOCK_eq)
   | H: context [LBLOCK] |- _ => add_nonredundant (LBLOCK_eq)
   | H: context [CBLOCKz] |- _ => add_nonredundant (CBLOCKz_eq)
   | H: context [LBLOCKz] |- _ => add_nonredundant (LBLOCKz_eq)
  end.

Ltac Omega1 := Omega (helper1 || helper2).

Ltac MyOmega :=
  rewrite ?length_list_repeat, ?skipn_length, ?map_length, 
   ?Zlength_map, ?Zlength_nil;
  pose proof CBLOCK_eq;
  pose proof CBLOCKz_eq;
  pose proof LBLOCK_eq;
  pose proof LBLOCKz_eq;
  Omega1.
(*** End Omega stuff ***)

Local Open Scope Z.

Local Open Scope logic.

Lemma data_block_valid_pointer sh l p: sepalg.nonidentity sh -> Zlength l > 0 ->
      data_block sh l p |-- valid_pointer p.
Proof. unfold data_block. simpl; intros.
  apply andp_valid_pointer2. apply data_at_valid_ptr; auto; simpl.
  rewrite Z.max_r, Z.mul_1_l; omega.
Qed.

Lemma data_block_isbyteZ:
 forall sh data v, data_block sh data v = !! Forall isbyteZ data && data_block sh data v.
Proof.
unfold data_block; intros.
simpl.
normalize.
f_equal. f_equal. apply prop_ext. intuition.
Qed.

Lemma sizeof_tarray_tuchar:
 forall (n:Z), (n>=0)%Z -> (sizeof cenv_cs (tarray tuchar n) =  n)%Z.
Proof. intros.
 unfold sizeof,tarray; cbv beta iota.
  rewrite Z.max_r by omega.
  unfold alignof, tuchar; cbv beta iota.
  rewrite Z.mul_1_l. auto.
Qed.

Lemma isbyte_value_fits_tuchar:
  forall x, isbyteZ x -> value_fits tuchar (Vint (Int.repr x)).
Proof.
intros. hnf in H|-*; intros.
simpl. rewrite Int.unsigned_repr by repable_signed. 
  change Byte.max_unsigned with 255%Z. omega.
Qed.

Lemma Forall_map:
  forall {A B} (f: B -> Prop) (g: A -> B) al,
   Forall f (map g al) <-> Forall (f oo g) al.
Proof.
intros.
induction al; simpl; intuition; inv H1; constructor; intuition.
Qed.

Lemma Forall_sublist:
  forall {A} (f: A -> Prop) lo hi al,
   Forall f al -> Forall f (sublist lo hi al).
Proof.
intros. unfold sublist.
apply Forall_firstn. apply Forall_skipn. auto.
Qed.

Lemma Zlength_Zlist_to_intlist: 
  forall (n:Z) (l: list Z),
   (Zlength l = WORD*n)%Z -> Zlength (Zlist_to_intlist l) = n.
Proof.
intros.
rewrite Zlength_correct in *.
assert (0 <= n)%Z by ( change WORD with 4%Z in H; omega).
rewrite (length_Zlist_to_intlist (Z.to_nat n)).
apply Z2Nat.id; auto.
apply Nat2Z.inj. rewrite H.
rewrite Nat2Z.inj_mul.
f_equal. rewrite Z2Nat.id; omega.
Qed.

Lemma nth_intlist_to_Zlist_eq:
 forall d (n i j k: nat) al, (i < n)%nat -> (i < j*4)%nat -> (i < k*4)%nat -> 
    nth i (intlist_to_Zlist (firstn j al)) d = nth i (intlist_to_Zlist (firstn k al)) d.
Proof.
 induction n; destruct i,al,j,k; simpl; intros; auto; try omega.
 destruct i; auto. destruct i; auto. destruct i; auto.
 apply IHn; omega.
Qed.


Hint Resolve isbyteZ_sublist.


Lemma split2_data_block:
  forall  {cs: compspecs}  n sh data d,
  (0 <= n <= Zlength data)%Z ->
  data_block sh data d =
  (data_block sh (sublist 0 n data) d *
   data_block sh (sublist n (Zlength data) data) 
   (field_address0 (tarray tuchar (Zlength data)) [ArraySubsc n] d))%logic.
Proof.
  intros.
  unfold data_block. simpl. normalize.
  f_equal. f_equal.
  apply prop_ext.
  split; intro. split; apply Forall_sublist; auto.
  erewrite <- (sublist_same 0 (Zlength data)); auto.
  rewrite (sublist_split 0 n) by omega.
  apply Forall_app; auto.
  rewrite <- !sublist_map.
  unfold tarray.
  rewrite split2_data_at_Tarray_tuchar with (n1:=n) by (autorewrite with sublist; auto).
  autorewrite with sublist.
  reflexivity.  
Qed.

Lemma split3_data_block:
  forall  {cs: compspecs} lo hi sh data d,
  0 <= lo <= hi ->
  hi <= Zlength data  ->
  data_block sh data d = 
  (data_block sh (sublist 0 lo data) d *
   data_block sh (sublist lo hi data) 
   (field_address0 (tarray tuchar (Zlength data)) [ArraySubsc lo] d) *
   data_block sh (sublist hi (Zlength data) data) 
   (field_address0 (tarray tuchar (Zlength data)) [ArraySubsc hi] d))%logic.
Proof.
  intros.
  destruct (field_compatible0_dec (tarray tuchar (Zlength data)) [ArraySubsc hi] d).
 *
  rewrite (split2_data_block lo); try omega; trivial.
  rewrite sepcon_assoc. f_equal.
  rewrite (split2_data_block (hi-lo)); autorewrite with sublist; try omega.
  f_equal. f_equal.
  unfold field_address0 at 3. rewrite if_true by auto.
  rewrite !field_address0_offset.
  rewrite offset_offset_val. f_equal. rewrite add_repr. f_equal.
  simpl. omega.
  auto with field_compatible.
  rewrite !field_address0_offset.
  simpl. normalize.
  { hnf in f|-*; intuition.
  unfold tarray in *.
  unfold legal_alignas_type in H4|-*; simpl in H4|-*.
  rewrite nested_pred_ind in H4.
  rewrite nested_pred_ind.
  rewrite andb_true_iff in *. destruct H4; split; auto.
  unfold local_legal_alignas_type in *.
  rewrite andb_true_iff in *. destruct H4; split; auto.
  destruct (attr_alignas (attr_of_type tuchar)); auto.
  eapply Zle_is_le_bool. omega.  
  simpl sizeof in H6|-*.
  rewrite Z.max_r in * by omega. omega.
  make_Vptr d. red in H7|-*.
  simpl sizeof in H7|-*. simpl.
  rewrite Z.max_r in * by omega.
  rewrite <- (Int.repr_unsigned i). rewrite add_repr.
  pose proof (Int.unsigned_range i). 
  destruct (zlt (Int.unsigned i + lo) Int.modulus).
  rewrite Int.unsigned_repr by (change Int.max_unsigned with (Int.modulus-1); omega).
  omega.
  assert (Int.unsigned (Int.repr (Int.unsigned i + lo)) <= Int.unsigned i + lo);
    [ | omega].
  clear - H1; unfold Int.unsigned, Int.repr in *; destruct i; simpl in *.
  rewrite Int.Z_mod_modulus_eq.
  apply Zmod_le; omega.
  make_Vptr d; red in H8|-*.
  apply Z.divide_1_l.
  }
 auto with field_compatible.
 *
  apply pred_ext.
  unfold data_block at 1; simpl; entailer!.
  contradiction n; auto with field_compatible.
  unfold field_address0.
  if_tac. 
  contradiction n; clear n; hnf in H1|-*; intuition.
  unfold data_block at 2. simpl; normalize.
  saturate_local.
  destruct H5; contradiction.
Qed.


Global Opaque WORD.