%%%-------------------------------------------------------------------
%%% witness_page — where each line is on a photographed page (2026-10-29, From Exam to Mastery).
%%%
%%% The teacher photographs the whole paper after the exam (one phone for the class). Muse Spark reads and marks it and
%%% says where each line is, in thousandths of the photo; on 29 Oct its boxes were near but up to half a line off, so a
%%% crop of the student's step could show the printed question above it. The page itself says where the ink is: rows
%%% darker than their surroundings make bands, one a written or printed line. Every printed question and every student
%%% line on a page is put on its own band in reading order (question 1, its lines, question 2...), each on the band
%%% nearest Spark's box, no band used twice. A line with no band near enough keeps Spark's box with room around it.
%%%
%%%   place(Gray, W, H, Items) -> [Box | none]
%%%       Gray = W x H grey bytes (witness_media:gray_image/2), Items = [[L, T, R, B]] in thousandths, reading order
%%%       Box = #{x1, y1, x2, y2, w => 1000, h => 1000}, thousandths of the page
%%%   ink(Gray, W, H) -> InkRows            rows of 0/1, a pixel darker than its neighbourhood
%%%   bands(InkRows, X0, X1) -> [{Y0, Y1}]  rows holding ink between X0 and X1 (a ruled line across them does not count)
%%%-------------------------------------------------------------------
-module(witness_page).
-export([place/4, ink/3, bands/3, loose/1]).

%% the neighbourhood a pixel is compared with (pixels each way, at the 600-wide working size)
-define(K, 12).
%% a pixel is ink when it is darker than this share of its neighbourhood, and darker than this grey
-define(SHARE, 0.78).
-define(DARK, 175).

place(Gray, W, H, Items) when byte_size(Gray) =:= W * H, Items =/= [] ->
    Ink = ink(Gray, W, H),
    L = lists:min([A || [A, _, _, _] <- Items]) * W / 1000, R = lists:max([C || [_, _, C, _] <- Items]) * W / 1000,
    X0 = max(0, trunc(L - 0.04 * W)), X1 = min(W, trunc(R + 0.06 * W)),
    Bands = bands(Ink, X0, X1),
    Centres = [(T + B) / 2000 * H || [_, T, _, B] <- Items],
    Picks = align(Centres, [(A + Z) / 2 || {A, Z} <- Bands]),
    InkT = list_to_tuple(Ink),
    [case Pick of
         none -> none;
         J ->
             {Y0, Y1} = lists:nth(J, Bands), Cy = (T + B) / 2000 * H, Bh = (B - T) / 1000 * H,
             case abs(Cy - (Y0 + Y1) / 2) > 2.5 * Bh + 6 of
                 true -> none;                                         %% nearest free band is another line
                 false ->
                     Xa = max(0, trunc(Lb / 1000 * W - 0.06 * W)), Xb = min(W, trunc(Rb / 1000 * W + 0.1 * W)),
                     {Xl, Xr} = case cols(InkT, Y0, Y1, Xa, Xb) of none -> {Xa, Xb}; E -> E end,
                     #{x1 => round(Xl * 1000 / W), y1 => round(Y0 * 1000 / H), x2 => round(Xr * 1000 / W),
                       y2 => round(Y1 * 1000 / H), w => 1000, h => 1000}
             end
     end || {[Lb, T, Rb, B], Pick} <- lists:zip(Items, Picks)];
place(_, _, _, Items) -> [none || _ <- Items].

%% Spark's own box with room around it, for a line the page could not place.
loose([L, T, R, B]) when R > L, B > T ->
    Ph = (B - T), #{x1 => max(0, L - 30), y1 => max(0, T - Ph), x2 => min(1000, R + 60), y2 => min(1000, B + Ph), w => 1000, h => 1000};
loose(_) -> none.

%% ---------------------------------------------------------------- ink
ink(Gray, W, H) ->
    Rows = [binary_to_list(binary:part(Gray, Y * W, W)) || Y <- lists:seq(0, H - 1)],
    HSums = [hsum(R, W) || R <- Rows],                                 %% each pixel's row window, summed
    VSums = vsum(HSums, H),                                            %% then the column window over those
    Aw = list_to_tuple([min(X + ?K, W - 1) - max(X - ?K, 0) + 1 || X <- lists:seq(0, W - 1)]),
    [begin
         Ah = min(Y + ?K, H - 1) - max(Y - ?K, 0) + 1,
         [case P < ?DARK andalso P * Ah * element(X, Aw) < ?SHARE * S of true -> 1; false -> 0 end
          || {X, P, S} <- lists:zip3(lists:seq(1, W), Row, Sum)]
     end || {Y, Row, Sum} <- lists:zip3(lists:seq(0, H - 1), Rows, VSums)].

%% the sum of the K pixels each side of every pixel in a row
hsum(Row, W) ->
    Pre = list_to_tuple(prefix(Row)),                                  %% Pre[i] = sum of the first i - 1 pixels
    [element(min(X + ?K, W - 1) + 2, Pre) - element(max(X - ?K, 0) + 1, Pre) || X <- lists:seq(0, W - 1)].

prefix(L) -> lists:reverse(lists:foldl(fun(V, [S | _] = Acc) -> [S + V | Acc] end, [0], L)).

%% the same down the columns: a running sum of the rows' window sums
vsum(HSums, H) ->
    T = list_to_tuple(HSums),
    Zero = [0 || _ <- element(1, T)],
    Add = fun(A, B) -> lists:zipwith(fun erlang:'+'/2, A, B) end,
    Sub = fun(A, B) -> lists:zipwith(fun erlang:'-'/2, A, B) end,
    First = lists:foldl(fun(Y, Acc) -> Add(Acc, element(Y + 1, T)) end, Zero, lists:seq(0, min(?K, H - 1))),
    {Out, _} = lists:mapfoldl(
        fun(Y, Cur) ->
            In = Y + ?K + 1, Gone = Y - ?K,
            C1 = case In =< H - 1 of true -> Add(Cur, element(In + 1, T)); false -> Cur end,
            C2 = case Gone >= 0 of true -> Sub(C1, element(Gone + 1, T)); false -> C1 end,
            {Cur, C2}
        end, First, lists:seq(0, H - 1)),
    Out.

%% ---------------------------------------------------------------- bands
bands(Ink, X0, X1) when X1 > X0 ->
    Wd = X1 - X0,
    Rows = [begin C = lists:sum(lists:sublist(R, X0 + 1, Wd)), C >= 2 andalso C / Wd < 0.5 end || R <- Ink],
    Runs = runs(Rows, 0, none, []),
    [B || {A, Z} = B <- join(Runs, []), Z - A >= 4];
bands(_, _, _) -> [].

runs([], Y, Start, Acc) -> lists:reverse(case Start of none -> Acc; _ -> [{Start, Y} | Acc] end);
runs([true | T], Y, none, Acc) -> runs(T, Y + 1, Y, Acc);
runs([true | T], Y, S, Acc) -> runs(T, Y + 1, S, Acc);
runs([false | T], Y, none, Acc) -> runs(T, Y + 1, none, Acc);
runs([false | T], Y, S, Acc) -> runs(T, Y + 1, none, [{S, Y} | Acc]).

%% a descender's gap of a row or three does not split a line
join([], Acc) -> lists:reverse(Acc);
join([{A, Z} | T], [{Pa, Pz} | Acc]) when A - Pz =< 3 -> join(T, [{Pa, Z} | Acc]);
join([B | T], Acc) -> join(T, [B | Acc]).

%% the first and last column holding ink between rows Y0 and Y1; a column whose ink runs on above and below the line is
%% a rule through it (a ruled page's margin, 29 Oct), not the student's writing
cols(InkT, Y0, Y1, Xa, Xb) ->
    %% a row inked across most of the width is a ruled line inside the band, not writing
    Rows = [R || Y <- lists:seq(Y0, Y1 - 1), R <- [lists:sublist(element(Y + 1, InkT), Xa + 1, Xb - Xa)], lists:sum(R) < 0.5 * (Xb - Xa)],
    %% a stroke of writing crosses more than one row; a lone speck (a faint rule's dot, the paper's grain) does not count
    Sum = lists:foldl(fun(R, Acc) -> lists:zipwith(fun erlang:'+'/2, Acc, R) end, [0 || _ <- lists:seq(Xa, Xb - 1)], Rows),
    Any0 = [case C >= 2 of true -> 1; false -> 0 end || C <- Sum],
    H = tuple_size(InkT),
    Above = case Y0 - 4 >= 0 of true -> lists:sublist(element(Y0 - 4 + 1, InkT), Xa + 1, Xb - Xa); false -> [0 || _ <- Any0] end,
    Below = case Y1 + 3 < H of true -> lists:sublist(element(Y1 + 3 + 1, InkT), Xa + 1, Xb - Xa); false -> [0 || _ <- Any0] end,
    %% a photographed rule leans a little: it may sit a column or two over above and below
    Any = [case {A, U, D} of {1, 1, 1} -> 0; _ -> A end || {A, U, D} <- lists:zip3(Any0, spread(Above), spread(Below))],
    case [I || {I, 1} <- lists:zip(lists:seq(0, length(Any) - 1), Any)] of
        [] -> none;
        Is -> {Xa + hd(Is), Xa + lists:last(Is) + 1}
    end.

%% each column marked when it or one of the two each side is
spread(L) ->
    T = list_to_tuple(L), N = tuple_size(T),
    [lists:max([element(J, T) || J <- lists:seq(max(1, I - 2), min(N, I + 2))]) || I <- lists:seq(1, N)].

%% ---------------------------------------------------------------- reading order
%% Items (their centres, in reading order) onto bands (top to bottom), in order, none shared, least distance in all:
%% [J | none] per item, J the band's place (1-based). Fewer bands than items: none are placed.
align(Cs, Bs) when length(Bs) < length(Cs) -> [none || _ <- Cs];
align(Cs, Bs) ->
    N = length(Cs), M = length(Bs), CT = list_to_tuple(Cs), BT = list_to_tuple(Bs),
    Row0 = list_to_tuple([0.0 || _ <- lists:seq(0, M)]),
    %% D(i, j): least cost of the first i items on the first j bands; Take(i, j) whether item i sits on band j
    {Rows, Takes} = lists:foldl(
        fun(I, {[Prev | _] = Ds, Ts}) ->
            {RowL, TakeL} = lists:foldl(
                fun(J, {[Left | _] = R, Tk}) ->
                    Inf = 1.0e18,
                    TakeC = case element(J, Prev) of P when P >= Inf -> Inf; P -> P + abs(element(I, CT) - element(J, BT)) end,
                    case TakeC =< Left of true -> {[TakeC | R], [true | Tk]}; false -> {[Left | R], [false | Tk]} end
                end, {[1.0e18], []}, lists:seq(1, M)),
            {[list_to_tuple(lists:reverse(RowL)) | Ds], [list_to_tuple([false | lists:reverse(TakeL)]) | Ts]}
        end, {[Row0], []}, lists:seq(1, N)),
    _ = Rows,
    Picks = back(N, M, list_to_tuple(lists:reverse(Takes)), #{}),
    [maps:get(I, Picks, none) || I <- lists:seq(1, N)].

back(0, _, _, Acc) -> Acc;
back(_, 0, _, Acc) -> Acc;
back(I, J, Takes, Acc) ->
    case element(J + 1, element(I, Takes)) of
        true -> back(I - 1, J - 1, Takes, Acc#{I => J});
        false -> back(I, J - 1, Takes, Acc)
    end.
