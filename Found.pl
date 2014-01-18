#!/usr/bin/env perl
use Mojolicious::Lite;
use MongoDB;
use MongoDB::OID;
use String::Approx 'amatch';

my $mongo_client = MongoDB::MongoClient->new
(
  host => 'linus.mongohq.com',
  port => 10089,
  db_name => 'LF',
  username => 'found',
  password => 'mojo',
);

my $db = $mongo_client->get_database('LF');

my $losts = $db->get_collection('Lost');
my $founds = $db->get_collection('Found');

my @all_losts = ($losts->query({}))->all;
my @all_founds = ($founds->query({}))->all;

get '/' => sub
{
  my $self = shift;
  $self->render(text => 'Lost and Found End Point');
};

post '/run' => sub { &match_maker; shift->render(text => 'YEAH'); };

get '/ios-7/end/lost' => sub { shift->render(json => \@all_founds) };
get '/ios-7/end/found' => sub { shift->render(json => \@all_losts ) };

sub match_maker
{
  my @unimp = qw(the of to and a in is it you that he was for on are with as I his they be at one have and this);

  my $mongo_client = MongoDB::MongoClient->new
  (
    host => 'linus.mongohq.com',
    port => 10089,
    db_name => 'LF',
    username => 'found',
    password => 'mojo',
  );

  my $db = $mongo_client->get_database('LF');
  my $losts = $db->get_collection('Lost');
  my $founds = $db->get_collection('Found');

  my $lost_c = $losts->query( {Matched => 0} );

  while(my $lost = $lost_c->next)
  {
    my $lost_ref = MongoDB::DBRef->new( db => 'LF', ref => $losts, id => $lost->{_id} );
    my $best_ref;
    my $best_total = 0;

    # Lost Vars for matching
    my $l_loc = $lost->{Location};
    my $l_desc = $lost->{Description};
    my $l_item = $lost->{Item};
    my @l_tags = @{ $lost->{Tags}};

    my $found_c = $founds->query({Matched => 0});

    while(my $found = $found_c->next)
    {
      my $found_ref = MongoDB::DBRef->new( db => 'LF', ref => $founds, id => $found->{_id} );

      # Found Vars for matching
      my $f_loc = $found->{Location};
      my $f_desc = $found->{Description};
      my $f_item = $found->{Item};
      my @f_tags = @{ $found->{Tags}};

      my $total = 0;

      if(amatch($l_loc,["i"],$f_loc))
      {
        foreach my $tagl (@l_tags)
        {
          $tagl =~ s/\s//g;
          next if( (length($tagl) < 2) || grep(/^$tagl$/, @unimp) );
          foreach my $tagf (@f_tags)
          {
            $tagf =~ s/^\s//g;
            next if( (length($tagf) < 2) || grep(/^$tagf$/, @unimp) );
            if(lc($tagl) eq lc($tagf))    { $total++;   next; }
            if(amatch($tagl,["i"],$tagf)) { $total+=.9; next; }
            if(index($tagl, $tagf) != -1) { $total+=.2; next; }
            if(index($tagf, $tagl) != -1) { $total+=.2; next; }
          }
        }
        if($total > $best_total) { $best_total = $total; $best_ref = $found_ref; }
      }
    }
    if($best_ref && $best_total > 1)
    {
      $losts->update({ _id => $lost_ref->id }, { '$set' => { Matched => 1, PMatch_id => $best_ref->id } }, { 'upsert' => 1 } );
      $founds->update({ _id => $best_ref->id }, { '$set' => { Matched => 1, PMatch_id => $lost_ref->id } }, { 'upsert' => 1 } );
    }
  }
}
app->start;