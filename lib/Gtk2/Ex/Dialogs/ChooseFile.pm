package Gtk2::Ex::Dialogs::ChooseFile;
###############################################################################
#  Gtk2::Ex::Dialogs::ChooseFile - Provides a file selection dialog.
#  Copyright (C) 2005  Open Door Software Inc. <ods@opendoorsoftware.com>
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
###############################################################################
use strict;

BEGIN {
	use vars qw( $VERSION $parent_window $title $icon $text
                 $destroy_with_parent $modal $no_separator );
    $VERSION = '0.09';
}

use Carp;
use Cwd;
use Gtk2;
use Gtk2::Ex::Constants qw( :truth :pad :pack :align :justify );

sub import {
    my $class = shift();
    my $cfg = undef;

    if ( @_ % 2 == 0 ) {
        $cfg = { @_ };
    } elsif ( @_ % 2 >= 1 ) {
        croak( $class . " class received an uneven argument list." );
    } else {
        $cfg = {};
    }

    #: documented:
    $Gtk2::Ex::Dialogs::ChooseFile::title               =
     $cfg->{title}               || '';
    $Gtk2::Ex::Dialogs::ChooseFile::path                =
     $cfg->{path}                || getcwd();
    $Gtk2::Ex::Dialogs::ChooseFile::modal               =
     $cfg->{modal}               || FALSE;
    $Gtk2::Ex::Dialogs::ChooseFile::parent_window       =
     $cfg->{parent_window}       || undef;
    $Gtk2::Ex::Dialogs::ChooseFile::destroy_with_parent =
     $cfg->{destroy_with_parent} || FALSE;
    $Gtk2::Ex::Dialogs::ChooseFile::must_exist          =
     $cfg->{must_exist}          || FALSE;
    #: undocumented:
    $Gtk2::Ex::Dialogs::ChooseFile::_action             =
     $cfg->{_action}             || 'open';
}


=head1 NAME

Gtk2::Ex::Dialogs::ChooseFile - Provides a file selection dialog.

=head1 SYNOPSIS

 use Gtk2::Ex::Dialogs::ChooseFile ( destroy_with_parent => TRUE,
                                     modal => TRUE );

 # do some stuff like creating your app's main $window then,
 # to ensure that all messages use the right parent, set it:
 $Gtk2::Ex::Dialogs::ChooseFile::parent_window = $window;

 # now popup a new dialog for opening a file
 my $file = ask_to_open
             Gtk2::Ex::Dialogs::ChooseFile ( "/path/to/something" );

 # ok, now we need to save (as...) a file
 my $save = ask_to_save
             Gtk2::Ex::Dialogs::ChooseFile ( "/path/to/something" );

=head1 DESCRIPTION

This module provides a simple file chooser api that wraps Gtk2::FileChooser
objectively. The objective is a simple ways to prompt a user to open or save
a file.

=head1 OPTIONS

All public methods (and the entire class) support the following options:

=over

=item B<title> => STRING

The text string to use as the title of the dialog window. Defaults to either
"Open" or "Save" based on the action context.

=item B<path> => STRING

The path to a file or directory to initialize the dialog with. Defaults to the
current working directory.

=item B<parent_window> => Gtk2::Window

Reference to the main application window.

=item B<destroy_with_parent> => BOOL

When the B<parent_window> is destroyed, what do we do? Defaults to FALSE.

=item B<modal> => BOOL

Does this dialog make the B<parent_window> freeze while the dialog exists.
Defaults to FALSE.

=item B<must_exist> => BOOL

The end-user must supply a path to an existing file or directory. Should the
end-user provide a non-existant path, the dialog will be respawned until an
existing file is chosen. Defaults to FALSE.

=back

=head1 PUBLIC METHODS

=over

=item OBJECT = B<new> ( OPTIONS | PATH )

Create a Gtk2::FileChooserDialog with the options given and show it to the
end-user. Once the user has selected a file return only the path to the file
and clean up. In the special case of being passed only one argument, all
options are set to defaults and the one argument is used as the B<path>
argument.

=back

=cut

sub new {
    my $proto = shift();
    my $class = ref($proto) || $proto;
    my $cfg = undef;

	if ( @_ % 2 == 0 ) {
        $cfg = { @_ };
    } elsif ( @_ == 1 ) {
        $cfg = { path => $_[0] };
    } else {
        $cfg = {};
    }

    #: documented:
	$cfg->{title}               ||= $Gtk2::Ex::Dialogs::ChooseFile::title;
	$cfg->{path}                ||= $Gtk2::Ex::Dialogs::ChooseFile::path;
	$cfg->{parent_window}       ||= $Gtk2::Ex::Dialogs::ChooseFile::parent_window;
	$cfg->{destroy_with_parent} ||= $Gtk2::Ex::Dialogs::ChooseFile::destroy_with_parent;
	$cfg->{modal}               ||= $Gtk2::Ex::Dialogs::ChooseFile::modal;
	$cfg->{must_exist}          ||= $Gtk2::Ex::Dialogs::ChooseFile::must_exist;
    #: undocumented:
    $cfg->{_action}             ||= $Gtk2::Ex::Dialogs::ChooseFile::_action;


    my @options = ( $cfg->{title}, $cfg->{parent_window}, $cfg->{_action} );
    push( @options, 'gtk-cancel', 'reject' );
    if ( $cfg->{_action} =~ /^save/ ) {
        push( @options, 'gtk-save', 'accept' );
    } else {
        push( @options, 'gtk-open', 'accept' );
    }
	my $dialog = new Gtk2::FileChooserDialog ( @options );
    $dialog->set_select_multiple( FALSE );

    $dialog->set_modal( TRUE )
     unless not $cfg->{modal};

    $dialog->set_destroy_with_parent( TRUE )
     unless not $cfg->{destroy_with_parent};

    if ( $cfg->{path} ) {
        if ( $cfg->{path} =~ m!^\./! ) {
            my $CWD = getcwd();
            $cfg->{path} =~ s!^\./!$CWD/!;
        }
        if ( -d $cfg->{path} ) { $dialog->set_current_folder( $cfg->{path} ); }
        else { $dialog->set_filename( $cfg->{path}       ); }
    } else { $dialog->set_current_folder( getcwd()     ); }

    my $path = '';
    my $run = $dialog->run();
    while ( $run  eq 'accept' ) {
        $path = $dialog->get_filename();
        last unless $cfg->{must_exist} && not -f $path;
        $run = $dialog->run();
    }

    $dialog->destroy();
    $path = '' unless $run eq 'accept';
	return( $path );
}

=over

=item RESPONSE = B<ask_to_open> ( OPTIONS | PATH )

Supports all the same arguments as new(). This will create a new
Gtk2::Ex::Dialogs::ChooseFile, with some specific defaults, and return
the user's response. In the event of being given only one argument,
it will be used as the B<path> option.

=back

=cut

sub ask_to_open {
    my $class = shift();
    if ( @_ % 2 == 0 ) {
        my %options = ( title => 'Open', '_action' => 'open', @_ );
        return( new Gtk2::Ex::Dialogs::ChooseFile ( %options ) );
    } else {
        if ( @_ == 1 ) {
            return( new Gtk2::Ex::Dialogs::ChooseFile ( title => 'Open',
                                                        'path' => $_[0],
                                                        '_action' => 'open' ) );
        } else {
            croak( 'ask_to_open ' . $class . ' received an uneven argument list.' );
        }
    }
}

=over

=item RESPONSE = B<ask_to_save> ( OPTIONS | PATH )

Supports all the same arguments as new(). This will create a new
Gtk2::Ex::Dialogs::ChooseFile, with some specific defaults, and return
the user's response. In the event of being given only one argument,
it will be used as the B<path> option.

=back

=cut

sub ask_to_save {
    my $class = shift();
    if ( @_ % 2 == 0 ) {
        my %options = ( title => 'Save', '_action' => 'save', @_ );
        return( new Gtk2::Ex::Dialogs::ChooseFile ( %options ) );
    } else {
        if ( @_ == 1 ) {
            return( new Gtk2::Ex::Dialogs::ChooseFile ( 'path' => $_[0],
                                                        title => 'Save',
                                                        '_action' => 'save' ) );
        } else {
            croak( 'ask_to_save ' . $class . ' received an uneven argument list.' );
        }
    }
}

#
# PRIVATE METHODS
#

1;

__END__

=head1 SEE ALSO

 Gtk2::FileChooser
 Gtk2::FileChooserDialog
 Gtk2::Ex::Dialogs
 Gtk2::Ex::Dialogs::ChooseDirectory
 Gtk2::Ex::Dialogs::ChoosePreviewFile
 Gtk2::Ex::Dialogs::ErrorMsg
 Gtk2::Ex::Dialogs::Message
 Gtk2::Ex::Dialogs::Question

=head1 BUGS

Please report any bugs to the mailing list.

=head1 MAILING LIST

 http://opendoorsoftware.com/lists/gtk2-ex-list
 gtk2-ex-list@opendoorsoftware.com

=head1 AUTHORS

 Kevin C. Krinke, <kckrinke@opendoorsoftware.com>
 James Greenhalgh, <jgreenhalgh@opendoorsoftware.com>

=head1 COPYRIGHT AND LICENSE

 Gtk2::Ex::Dialogs::ChooseFile - Provides a file selection dialog.
 Copyright (C) 2005 Open Door Software Inc. <ods@opendoorsoftware.com>

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

=cut
