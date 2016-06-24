Require Import RamifyCoq.lib.List_ext.
Require Import RndHoare.sigma_algebra.
Require Import RndHoare.measurable_function.
Require Import RndHoare.regular_conditional_prob.
Require Import RndHoare.random_oracle.
Require Import RndHoare.random_history_order.
Require Import RndHoare.random_history_conflict.
Require Import RndHoare.history_anti_chain.
Require Import RndHoare.random_variable.
Require Import RndHoare.meta_state.
Require Import Coq.Classes.Equivalence.
Require Import Coq.Classes.Morphisms.

Section CutStream.

Context {ora: RandomOracle} {SFo: SigmaAlgebraFamily RandomHistory} {HBSFo: HistoryBasedSigF ora} {state: Type} {state_sigma: SigmaAlgebra state}.

Variable (filter: nat -> measurable_set (MetaState state)).

Variables (Omegas: RandomVarDomainStream) (l: ProgStateStream Omegas state) (dir: ConvergeDir l).

Inductive local_step_label: nat -> RandomHistory -> nat -> nat -> Prop :=
  | label_0: forall h, dir 0 h -> local_step_label 0 h 0 0
  | label_m: forall n h' h m r, dir (S n) h -> local_step_label n h' m r -> prefix_history h' h -> 
               (forall s, l (S n) h s -> ~ filter m s) -> local_step_label (S n) h m (S r)
  | label_Sm: forall n h' h m r, dir (S n) h -> local_step_label n h' m r -> prefix_history h' h -> 
               (forall s, l (S n) h s -> filter m s) -> local_step_label (S n) h (S m) 0
.

Inductive status: Type :=
  | ActiveBranch: nat -> status
  | SingleStreamEnd: nat -> status
  | FullStreamEnd: status.

Inductive local_step_rev: forall (m r: nat) (h: RandomHistory) (k: status), Prop :=
  | rev_ActiveBranch:
      forall m r h n,
        local_step_label n h m r ->
        local_step_rev m r h (ActiveBranch n)
  | rev_SingleStreamEnd:
      forall m r h n,
        (forall n' h', prefix_history h' h -> ~ local_step_label n' h' m r) ->
        local_step_label n h (S m) 0 ->
        local_step_rev m r h (SingleStreamEnd n)
  | rev_FullStreamEnd:
      forall m r h,
        (forall n' h', prefix_history h' h -> ~ local_step_label n' h' m r) ->
        (forall n' h', prefix_history h' h -> ~ local_step_label n' h' (S m) 0) ->
        (limit_domain Omegas) h ->
        local_step_rev m r h FullStreamEnd
.

Inductive raw_sdomains: forall (m r: nat) (h: RandomHistory), Prop :=
  | dom_ActiveBranch:
      forall m r h n, local_step_rev m r h (ActiveBranch n) -> raw_sdomains m r h
  | dom_SingleStreamEnd:
      forall m r h n, local_step_rev m r h (SingleStreamEnd n) -> raw_sdomains m r h
  | dom_FullStreamEnd:
      forall m r h, local_step_rev m r h FullStreamEnd -> raw_sdomains m r h
.

Inductive raw_sdir: forall (m r: nat) (h: RandomHistory), Prop :=
  | dir_ActiveBranch:
      forall m r h n, local_step_rev m r h (ActiveBranch n) -> raw_sdir m r h
.

Inductive raw_sstate: forall (m r: nat) (h: RandomHistory) (s: MetaState state), Prop :=
  | state_ActiveBranch:
      forall m r h n s, local_step_rev m r h (ActiveBranch n) -> l n h s -> raw_sstate m r h s
  | state_SingleStreamEnd:
      forall m r h n s, local_step_rev m r h (SingleStreamEnd n) -> l n h s -> raw_sstate m r h s
  | state_FullStreamEnd:
      forall m r h s, local_step_rev m r h FullStreamEnd -> (limit l dir) h s -> raw_sstate m r h s
.

Definition raw_fdomains (m: nat) (h: RandomHistory): Prop := raw_sdomains m 0 h.

Definition raw_fdir (m: nat) (h: RandomHistory): Prop := raw_sdir m 0 h.

Definition raw_fstate (m: nat) (h: RandomHistory) (s: MetaState state): Prop := raw_sstate m 0 h s.

Lemma labeled_in_dir: forall n h m r,
  local_step_label n h m r ->
  dir n h.
Proof.
  intros.
  inversion H; auto.
Qed.

Lemma two_labeled_prefix_eq: forall n h h1 h2 m1 r1 m2 r2,
  local_step_label n h1 m1 r1 ->
  local_step_label n h2 m2 r2 ->
  prefix_history h1 h ->
  prefix_history h2 h ->
  h1 = h2.
Proof.
  intros.
  pose proof labeled_in_dir _ _ _ _ H.
  pose proof labeled_in_dir _ _ _ _ H0.
  apply (anti_chain_not_comparable' (dir n)); auto.
  eapply prefix_history_comparable; eauto.
Qed.

Lemma local_step_label_functionality: forall n h m1 r1 m2 r2,
  local_step_label n h m1 r1 ->
  local_step_label n h m2 r2 ->
  m1 = m2 /\ r1 = r2.
Proof.
  intros.
  revert h m1 m2 r1 r2 H H0; induction n; intros.
  + inversion H; inversion H0; subst.
    auto.
  + inversion H; inversion H0; subst.
    - assert (h' = h'0) by (eapply (two_labeled_prefix_eq n h); eauto).
      subst h'0.
      specialize (IHn h' m1 m2 r r0 H3 H11).
      destruct IHn; subst; auto.
    - assert (h' = h'0) by (eapply (two_labeled_prefix_eq n h); eauto).
      subst h'0.
      specialize (IHn h' _ _ _ _ H3 H11).
      destruct IHn; subst; exfalso.
      pose proof PrFamily.rf_complete _ _ (l (S n)) h as [s ?]; [eapply MeasurableSubset_in_domain; eauto |].
      specialize (H13 _ H1).
      specialize (H5 _ H1).
      auto.
    - assert (h' = h'0) by (eapply (two_labeled_prefix_eq n h); eauto).
      subst h'0.
      specialize (IHn h' _ _ _ _ H3 H11).
      destruct IHn; subst; exfalso.
      pose proof PrFamily.rf_complete _ _ (l (S n)) h as [s ?]; [eapply MeasurableSubset_in_domain; eauto |].
      specialize (H13 _ H1).
      specialize (H5 _ H1).
      auto.
    - assert (h' = h'0) by (eapply (two_labeled_prefix_eq n h); eauto).
      subst h'0.
      specialize (IHn h' _ _ _ _ H3 H11).
      destruct IHn; subst; auto.
Qed.

Lemma local_step_label_strict_order: forall n1 n2 h1 h2 m1 r1 m2 r2,
  n1 < n2 ->
  prefix_history h1 h2 ->
  local_step_label n1 h1 m1 r1 ->
  local_step_label n2 h2 m2 r2 ->
  m1 < m2 \/ m1 = m2 /\ r1 < r2.
Proof.
  intros.
  remember (n2 - n1 - 1) as Delta.
  assert (n2 = Delta + (S n1)) by omega.
  subst n2; clear HeqDelta H.
  revert h2 m2 r2 H0 H2; induction Delta; intros.
  + simpl in H2.
    inversion H2; subst.
    - assert (h' = h1) by (eapply (two_labeled_prefix_eq n1 h2); eauto).
      subst h'.
      destruct (local_step_label_functionality _ _ _ _ _ _ H1 H4).
      subst; right; omega.
    - assert (h' = h1) by (eapply (two_labeled_prefix_eq n1 h2); eauto).
      subst h'.
      destruct (local_step_label_functionality _ _ _ _ _ _ H1 H4).
      subst; left; omega.
  + simpl in H2.
    inversion H2; subst.
    - assert (prefix_history h1 h').
      Focus 1. {
        apply (proj_in_anti_chain_unique (dir n1) _ _ h2); auto.
        + apply (ConvergeDir_mono dir n1 (Delta + S n1)); [omega |].
          eapply labeled_in_dir; eauto.
        + eapply labeled_in_dir; eauto.
      } Unfocus.
      specialize (IHDelta _ _ _ H H4).
      omega.
    - assert (prefix_history h1 h').
      Focus 1. {
        apply (proj_in_anti_chain_unique (dir n1) _ _ h2); auto.
        + apply (ConvergeDir_mono dir n1 (Delta + S n1)); [omega |].
          eapply labeled_in_dir; eauto.
        + eapply labeled_in_dir; eauto.
      } Unfocus.
      specialize (IHDelta _ _ _ H H4).
      omega.
Qed.

Lemma local_step_rev_functionality: forall m r h k1 k2,
  local_step_rev m r h k1 ->
  local_step_rev m r h k2 ->
  k1 = k2.
Proof.
  intros.
  inversion H; inversion H0; subst.
  + destruct (lt_eq_lt_dec n n0) as [[?H | ?] | ?H]; [| congruence |].
    - pose proof local_step_label_strict_order _ _ _ _ _ _ _ _ H2 (prefix_history_refl _) H1 H6.
      omega.
    - pose proof local_step_label_strict_order _ _ _ _ _ _ _ _ H2 (prefix_history_refl _) H6 H1.
      omega.
  + exfalso; apply (H6 n h); auto; apply prefix_history_refl.
  + exfalso; apply (H6 n h); auto; apply prefix_history_refl.
  + exfalso; apply (H1 n0 h); auto; apply prefix_history_refl.
  + destruct (lt_eq_lt_dec n n0) as [[?H | ?] | ?H]; [| congruence |].
    - pose proof local_step_label_strict_order _ _ _ _ _ _ _ _ H3 (prefix_history_refl _) H2 H8.
      omega.
    - pose proof local_step_label_strict_order _ _ _ _ _ _ _ _ H3 (prefix_history_refl _) H8 H2.
      omega.
  + exfalso; apply (H8 n h); auto; apply prefix_history_refl.
  + exfalso; apply (H1 n h); auto; apply prefix_history_refl.
  + exfalso; apply (H2 n h); auto; apply prefix_history_refl.
  + auto.
Qed.

Lemma raw_sdomains_legal_ind: forall m r,
  LegalHistoryAntiChain (raw_sdomains m r) ->
  LegalHistoryAntiChain (raw_sdomains m (S r)).
Proof.
Admitted.

Lemma raw_sdomains_same_covered: forall m r H H0,
  same_covered_anti_chain (Build_HistoryAntiChain _ (raw_sdomains m r) H) (Build_HistoryAntiChain _ (raw_sdomains m (S r)) H0).
Proof.
Admitted.

Lemma raw_sdomains_forward: forall m r H H0,
  future_anti_chain (Build_HistoryAntiChain _ (raw_sdomains m r) H) (Build_HistoryAntiChain _ (raw_sdomains m (S r)) H0).
Proof.
Admitted.

Lemma raw_sstate_partial_functionality: forall m r h s1 s2,
  raw_sstate m r h s1 -> raw_sstate m r h s2 -> s1 = s2.
Proof.
  intros.
  inversion H; inversion H0; subst;
  pose proof local_step_rev_functionality _ _ _ _ _ H1 H7;
  try congruence.
  + inversion H3; subst n0.
    apply (PrFamily.rf_partial_functionality _ _ (l n) h s1 s2 H2 H8).
  + inversion H3; subst n0.
    apply (PrFamily.rf_partial_functionality _ _ (l n) h s1 s2 H2 H8).
  + apply (PrFamily.rf_partial_functionality _ _ (limit l dir) h s1 s2 H2 H8).
Qed.

Lemma raw_sstate_sound: forall m r h s,
  raw_sstate m r h s -> raw_sdomains m r h.
Proof.
  intros.
  inversion H; subst.
  + eapply dom_ActiveBranch; eauto.
  + eapply dom_SingleStreamEnd; eauto.
  + eapply dom_FullStreamEnd; eauto.
Qed.

Lemma raw_sstate_complete: forall m r h,
  raw_sdomains m r h -> exists s, raw_sstate m r h s.
Proof.
  intros.
  inversion H; subst.
  + destruct (PrFamily.rf_complete _ _ (l n) h) as [s ?].
    - inversion H0; subst; auto.
      apply labeled_in_dir in H5.
      eapply MeasurableSubset_in_domain; eauto.
    - exists s.
      eapply state_ActiveBranch; eauto.
  + destruct (PrFamily.rf_complete _ _ (l n) h) as [s ?].
    - inversion H0; subst; auto.
      apply labeled_in_dir in H6.
      eapply MeasurableSubset_in_domain; eauto.
    - exists s.
      eapply state_SingleStreamEnd; eauto.
  + destruct (PrFamily.rf_complete _ _ (limit l dir) h) as [s ?].
    - inversion H0; subst; auto.
    - exists s.
      eapply state_FullStreamEnd; eauto.
Qed.

Lemma raw_sstate_preserve: forall m r H (P: measurable_set (MetaState state)),
  PrFamily.is_measurable_set (fun h => raw_sdomains m r h /\ (forall s, raw_sstate m r h s -> P s)) (exist _ (raw_sdomains m r) H).
Admitted.

Lemma raw_sstate_inf_consist: forall m r h s,
  is_inf_history h ->
  raw_sstate m r h s ->
  s = NonTerminating _.
Proof.
  intros.
  destruct H0.
  + apply (inf_history_sound _ _ (l n) h); auto.
  + apply (inf_history_sound _ _ (l n) h); auto.
  + apply (inf_history_sound _ _ (limit l dir) h); auto.
Qed.

Lemma raw_sdir_in_raw_domains: forall m r,
  Included (raw_sdir m r) (raw_sdomains m r).
Proof.
  unfold Included, Ensembles.In.
  intros.
  inversion H; subst.
  eapply dom_ActiveBranch; eauto.
Qed.

Lemma raw_sdir_measurable: forall m r H,
  PrFamily.is_measurable_set (raw_sdir m r) (exist _ (raw_sdomains m r) H).
Admitted.

Lemma raw_sdir_forward: forall m r H H0,
  future_anti_chain (Build_HistoryAntiChain _ (raw_sdir m r) H) (Build_HistoryAntiChain _ (raw_sdir m (S r)) H0).
Proof.
Admitted.

Lemma raw_sdir_slow: forall m r h,
  (raw_sdir m r) h \/ (forall s, raw_sstate m r h s <-> raw_sstate m (S r) h s).
Proof.
Admitted.

Lemma init_raw_dom_is_limit_dom: forall (Omegas0: RandomVarDomainStream) m,
  (forall r h, Omegas0 r h = raw_sdomains m r h) ->
  (forall h, limit_domain Omegas0 h <-> raw_sdomains (S m) 0 h).
Admitted.

Lemma init_raw_state_is_limit_state: forall (Omegas0: RandomVarDomainStream) (l0: ProgStateStream Omegas0 state) (dir0: ConvergeDir l0) m,
  (forall r h, Omegas0 r h = raw_sdomains m r h) ->
  (forall r h, dir0 r h = raw_sdir m r h) ->
  (forall r h s, l0 r h s = raw_sstate m r h s) ->
  (forall h s, limit l0 dir0 h s <-> raw_sstate (S m) 0 h s).
Admitted.

Section ind.

Variable (m: nat).
Hypothesis (H: LegalHistoryAntiChain (raw_sdomains m 0)) (H0: is_measurable_subspace (raw_sdomains m 0)).

Definition sub_domain'' (r: nat): RandomVarDomain.
  refine (exist _ (raw_sdomains m r) _).
  assert (LegalHistoryAntiChain (raw_sdomains m r) /\ is_measurable_subspace (raw_sdomains m r)); [| tauto].
  induction r.
  + auto.
  + destruct IHr.
    pose proof raw_sdomains_legal_ind _ _ H1.
    split; auto.
    change (raw_sdomains m (S r)) with
        (Build_HistoryAntiChain _ (raw_sdomains m (S r)) H3: Ensemble _).
    apply is_measurable_subspace_same_covered with (Build_HistoryAntiChain _ (raw_sdomains m r) H1); auto.
    apply raw_sdomains_same_covered.
Defined.

Definition sub_domain': RandomVarDomainStream.
  refine (Build_RandomVarDomainStream sub_domain'' _ _).
  + intros; apply raw_sdomains_same_covered.
  + intros; apply raw_sdomains_forward.
Defined.

Definition sub_state': ProgStateStream sub_domain' state :=
  fun r =>
    Build_ProgState _ _ _
     (PrFamily.Build_MeasurableFunction (sub_domain'' r) _ _
       (raw_sstate m r)
       (raw_sstate_partial_functionality _ _)
       (raw_sstate_complete _ _)
       (raw_sstate_sound _ _)
       (raw_sstate_preserve _ _ _))
     (raw_sstate_inf_consist _ _).

Definition sub_dir'' (r: nat): MeasurableSubset (sub_domain'' r) :=
  exist _ (raw_sdir m r) (raw_sdir_measurable m r _).

Definition sub_dir': ConvergeDir sub_state'.
  refine (Build_ConvergeDir sub_domain' _ _ _ sub_dir'' _ _).
  + intros. apply raw_sdir_forward.
  + intros. apply raw_sdir_slow.
Defined.

Lemma init_dom_is_limit_dom': forall h, limit_domain sub_domain' h <-> raw_sdomains (S m) 0 h.
Proof.
  apply init_raw_dom_is_limit_dom.
  intros; reflexivity.
Qed.

Lemma legal_ind: LegalHistoryAntiChain (raw_sdomains (S m) 0).
Proof.
  constructor.
  hnf; intros.
  rewrite <- init_dom_is_limit_dom' in H2.
  rewrite <- init_dom_is_limit_dom' in H3.
  exact (@rand_consi _ _ (raw_anti_chain_legal (limit_domain sub_domain')) _ _ H1 H2 H3).
Qed.

Lemma measurable_ind: is_measurable_subspace (raw_sdomains (S m) 0).
  apply is_measurable_subspace_proper with (limit_domain sub_domain').
  + symmetry; rewrite Same_set_spec; exact init_dom_is_limit_dom'.
  + apply (proj2_sig (limit_domain sub_domain')).
Qed.

End ind.

Lemma local_step_label_00_iff: forall h n, n = 0 /\ dir 0 h <-> local_step_label n h 0 0.
Proof.
  intros.
  split; intros.
  + destruct H; subst; apply label_0; auto.
  + inversion H; subst; auto.
Qed.

Lemma local_step_rev_00_ActiveBranch_iff: forall h n, local_step_rev 0 0 h (ActiveBranch n) <-> n = 0 /\ dir 0 h.
Proof.
  intros.
  split; intros.
  + inversion H; subst.
    rewrite local_step_label_00_iff; auto.
  + constructor.
    rewrite local_step_label_00_iff in H; auto.
Qed.

Lemma local_step_rev_00_SingleStreamEnd_iff: forall h n, local_step_rev 0 0 h (SingleStreamEnd n) <-> False.
Proof.
  intros.
  split; [| tauto].
  intros.
  inversion H; subst.
  pose proof labeled_in_dir _ _ _ _ H5.
  destruct (fun HH => ConvergeDir_mono dir 0 n HH h H0) as [h' [? ?]]; [omega |].
  specialize (H1 0 h' H2).
  apply H1.
  rewrite <- local_step_label_00_iff; auto.
Qed.

Lemma local_step_rev_00_FullStreamEnd_iff: forall h, local_step_rev 0 0 h FullStreamEnd <-> Omegas 0 h /\ ~ dir 0 h.
Proof.
  intros.
  split; intros.
  + inversion H; subst.
    assert (~ covered_by h (dir 0)).
    Focus 1. {
      intros [h' [? ?]].
      specialize (H0 0 h' H3).
      rewrite <- local_step_label_00_iff in H0.
      tauto.
    } Unfocus.
    split.
    - rewrite ConvergeDir_uncovered_limit_domain_spec by eauto. auto.
    - intro; apply H3; exists h; split; [apply prefix_history_refl | auto].
  + destruct H.
    assert (~ covered_by h (dir 0)).
    Focus 1. {
      rewrite <- covered_by_is_element; [auto | exact H | exact (MeasurableSubset_in_domain _ _)].
    } Unfocus.
    constructor.
    - intros; intro.
      apply H1; exists h'.
      rewrite <- local_step_label_00_iff in H3.
      tauto.
    - intros; intro.
      pose proof labeled_in_dir _ _ _ _ H3.
      destruct (fun HH => ConvergeDir_mono dir 0 n' HH h' H4) as [h'' [? ?]]; [omega |].
      apply H1; exists h''; split; auto.
      eapply prefix_history_trans; eauto.
    - rewrite <- ConvergeDir_uncovered_limit_domain_spec by eauto.
      auto.
Qed.

Lemma local_step_rev_00_iff: forall h, (exists k, local_step_rev 0 0 h k) <-> Omegas 0 h.
Proof.
  intros.
  split; [intros [? ?] | intros].
  + inversion H; subst.
    - rewrite local_step_rev_00_ActiveBranch_iff in H.
      destruct H.
      eapply MeasurableSubset_in_domain; eauto.
    - rewrite local_step_rev_00_SingleStreamEnd_iff in H.
      tauto.
    - rewrite local_step_rev_00_FullStreamEnd_iff in H.
      tauto.
  + destruct (classic (dir 0 h)).
    - exists (ActiveBranch 0).
      rewrite local_step_rev_00_ActiveBranch_iff; auto.
    - exists FullStreamEnd.
      rewrite local_step_rev_00_FullStreamEnd_iff; auto.
Qed.

Lemma raw_sdomains_00_iff: forall h, raw_sdomains 0 0 h <-> Omegas 0 h.
Proof.
  intros.
  rewrite <- local_step_rev_00_iff.
  split; intros.
  + inversion H; subst; firstorder.
  + destruct H as [[? | ? |] ?].
    - eapply dom_ActiveBranch; eauto.
    - eapply dom_SingleStreamEnd; eauto.
    - apply dom_FullStreamEnd; auto.
Qed.

Lemma legal0_measure0: forall m, LegalHistoryAntiChain (raw_sdomains m 0) /\ is_measurable_subspace (raw_sdomains m 0).
Proof.
  intros.
  induction m.
  + split.
    - simpl.
      constructor; hnf; intros.
      rewrite raw_sdomains_00_iff in H0.
      rewrite raw_sdomains_00_iff in H1.
      exact (@rand_consi _ _ (raw_anti_chain_legal (Omegas 0)) _ _ H H0 H1).
    - apply is_measurable_subspace_proper with (Omegas 0).
      * rewrite Same_set_spec; exact raw_sdomains_00_iff.
      * apply (proj2_sig (Omegas 0)).
  + destruct IHm.
    split.
    - apply legal_ind; auto.
    - apply measurable_ind; auto.
Qed.

Definition sub_domain (m: nat): RandomVarDomainStream := sub_domain' m (proj1 (legal0_measure0 m)) (proj2 (legal0_measure0 m)).

Definition sub_state (m: nat): ProgStateStream (sub_domain m) state := sub_state' m (proj1 (legal0_measure0 m)) (proj2 (legal0_measure0 m)).

Definition sub_dir (m: nat): ConvergeDir (sub_state m) := sub_dir' m (proj1 (legal0_measure0 m)) (proj2 (legal0_measure0 m)).

End CutStream.